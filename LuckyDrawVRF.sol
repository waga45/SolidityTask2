// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

//幸运抽奖 VRF 分布式随机数
contract LuckyDrawVRF is VRFConsumerBaseV2Plus {
    uint256 public constant DECIMALS = 18;
    uint256 public constant ONE = 10**DECIMALS;
    uint256 subscriptionId;//订阅ID
    //测试协调器地址
    address vrfCoordinator;
    //代表使用哪个Gas Lane，不同价格的随机数
    bytes32 keyHash;
    //N个区块确认后再生成
    uint16 requestConfirmation =3;
    //回调gas费上限
    uint32 callbackGasLimit = 100000;
    //随机个数
    uint32 numWords= 1;
    //轮数
    uint256 public currentId;
    //记录  id-->活动详细
    mapping(uint256=>Join) records;
    //随机数请求id对应活动id--开奖才有
    mapping(uint256=>uint256) public requestidToJoinId;
    //是否有正在开奖
    uint8 hasProcessing=0;
    //最低价
    uint256 miniPrice;
    //总手续费
    uint256 totalFee;
    //合约所有者
    address contractOwner;

    struct Join  {
        //开始时间
        uint256 startTime;
        //结束时间
        uint256 endTime;
        //奖池总金额
        uint256 totalReward;
        //归属者
        address owner;
        //中奖者
        address winner;
        //参与门票--创建活动设置
        uint256 price;
        //是否已开奖
        bool open; 
        //参与者--金额
        mapping(address=>uint256) joins;
        //参与者地址列表
        address[] joinAddress;
    }
    //参与成功
    event EventJoinSuccess(address user,uint256 luckyId,uint256 price,uint256 timestamp);
    //发起开奖
    event EventDrawStart(address owner,uint256 luckyId,uint256 requestId,uint256 timestamp);
    //开奖成功
    event EventDrawWinnerSuccess(address winner,uint256 luckyId,uint256 requestId,uint256 timestamp);

    //提现
    event EventDrawSuccess(address owner,uint256 balance,uint256 timestamp);

    constructor(address _coordinator, uint256 _subscriptionId, bytes32 _keyHash,uint256 _miniPrice) VRFConsumerBaseV2Plus(_coordinator) {
        vrfCoordinator = _coordinator;
        s_vrfCoordinator = IVRFCoordinatorV2Plus(_coordinator);
        subscriptionId=_subscriptionId;
        keyHash=_keyHash;
        currentId=1;
        miniPrice = _miniPrice;
        contractOwner= msg.sender;
    }

    //创建抽检活动，支付一定数量以太坊,必须大于0，返回id
    function createLucky(uint256 _startTime,uint256 _endTime,uint256 _conditionPrice) public payable returns(uint256) {
        require(msg.sender!=address(0),"not alllowed join it");
        require(msg.value>0&&msg.value>=miniPrice,"create luck init reward must be big than zero");
        currentId += 1;
        //先取出来一个存储曹
        Join storage newJoin = records[currentId];
        newJoin.startTime=_startTime;
        newJoin.endTime = _endTime;
        newJoin.totalReward = msg.value;
        newJoin.owner = msg.sender;
        newJoin.price = _conditionPrice;
        newJoin.open=true;
        newJoin.joins[msg.sender] = msg.value;
        newJoin.joinAddress.push(msg.sender);
        return currentId;
    }

    //参与抽奖
    function joinLucky(uint256 id) public payable{
        require(msg.sender!=address(0),"correct join address");
        Join storage task =records[id];
        require(task.startTime<=block.timestamp&&task.endTime>block.timestamp,"current task has end");
        require(task.open==true, "current task has done");
        require(msg.value>=task.price,"join price must be big than tick price");
        require(task.joins[msg.sender]<=0,"you has join it,please waiting lucky going down");
        //满足条件，进行记录
        task.totalReward+=msg.value;
        task.joins[msg.sender]=msg.value;
        task.joinAddress.push(msg.sender);
        //回调通知
        emit EventJoinSuccess(msg.sender,id,msg.value,block.timestamp);
    }

    //开奖--只有创建人才能开
    function drawWinner(uint256 id) public {
        require(id >0,"please input drawId");
        require(hasProcessing<=0, "current has processingg draw");
        require(block.timestamp>records[id].startTime,"current task hasnt start");
        require(records[id].open==true,"current task has done");
        require(records[id].owner == msg.sender ,"you are no permission");
        require(records[id].joinAddress.length>0,"no join the persion");
        hasProcessing=1;
        //如果只有一个人参与，发起开奖自动将金额退回发起人
        if(records[id].joinAddress.length==1){
            (bool success, ) =records[id].owner.call{value:records[id].totalReward}("");
            require(success, "Transfer failed");
            records[id].open=false;
            records[id].winner=msg.sender;
            hasProcessing=0;
            //通知
            emit EventDrawWinnerSuccess(msg.sender, id, 0, block.timestamp);
        }else {
            uint256 requestId = s_vrfCoordinator.requestRandomWords(
                    VRFV2PlusClient.RandomWordsRequest({
                        keyHash: keyHash,
                        subId: subscriptionId,
                        requestConfirmations: requestConfirmation,
                        callbackGasLimit: callbackGasLimit,
                        numWords: numWords,
                        extraArgs: VRFV2PlusClient._argsToBytes(
                            VRFV2PlusClient.ExtraArgsV1({nativePayment: true})
                        )
                    })
                );
            requestidToJoinId[requestId]=id;
            emit EventDrawStart(msg.sender, id, requestId, block.timestamp);
        }
    }

    //接收随机数
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        require(requestidToJoinId[requestId]>0, "not exist task");
        uint256 id=requestidToJoinId[requestId];
        Join storage currentDraw = records[id];
        require(currentDraw.open==true,"current task has done");
        // 确保有参与者
        require(currentDraw.joinAddress.length > 0, "No participants");
        uint256 randomness = randomWords[0];
        // 使用随机数选择获胜者
        uint256 winnerIndex = randomness % currentDraw.joinAddress.length;
        address winner = currentDraw.joinAddress[winnerIndex];
        //计算手续费 rate
        uint256 fee=currentDraw.totalReward*(ONE/100);
        totalFee+=fee;
        // 发送奖励给获胜者
        (bool success, ) = winner.call{value: (currentDraw.totalReward-fee)}("");
        require(success, "Failed to send reward");
         //标记
        currentDraw.winner = winner;
        currentDraw.open=false;
        hasProcessing=0;

        //通知
        emit EventDrawWinnerSuccess(winner, id, requestId, block.timestamp);
    }

    //获取活动信息
    function getOneLuckyInfo(uint256 luckyId) public view returns(
        uint256 startTime,
        uint256 endTime,
        uint256 totalReward,
        address owner,
        address winner,
        uint256 price,
        bool open,
        uint256 joinNum
    ){
         Join storage jj=records[luckyId];
        return (jj.startTime,jj.endTime,jj.totalReward,jj.owner,jj.winner,jj.price,jj.open,jj.joinAddress.length);
    }   
    //获取某个抽奖活动人员参与金额
    function getLuckyJoinBalance(uint256 luckyId,address user) public view returns(uint256 amount){
        require(user!=address(0));
        Join storage jj=records[luckyId];
        return jj.joins[user];
    }

    function getTotalFee() public view returns(uint256){
        return totalFee;
    }
    //提现
    function withDraw() public payable onlyOwner{
        require(totalFee>0,"no full fee");
        uint256 temp = totalFee;
        totalFee=0;
        payable(contractOwner).transfer(temp);
        emit EventDrawSuccess(msg.sender,temp,block.timestamp);
    }

}
