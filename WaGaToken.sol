// SPDX-License-Identifier: MIT
pragma solidity >=0.8;
import "openzeppelin-solidity/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

//WGToken代币
contract WaGaToken is ReentrancyGuard{
    using SafeMath for uint256;
    //代币名称
    string public name ="WGToken";
    //代币简称
    string public symbol ="WGT";
    //单位 1WGT= 10** decimals
    uint256 public decimals = 18;
    //总供应量
    uint256 public totalSupply;
    //ERC20地址->余额
    mapping (address=>uint256) public balanceOf;
    //ERC20 授权供应量 {"user_address":{"addressA":xxx,"addrsssB":xxx}} 
    // 简单的说就是 ：我（用户地址），-->授权某个地址（第三方交易所或合约地址）-->能使用多少本代币
    mapping (address=>mapping (address=>uint256)) public allowance;
    address public  owner;
    //是否暂停交易
    bool private _paused;
    //转账成功事件
    event EventTransferSuccess(address from,address to,uint256 amount,uint256 balance,uint256 timestamp);
    event EventApprove(address owner,address spender,uint256 balance,uint256 timestamp);
    event EventBurn(address user,uint256 amount,uint256 timestamp);

    constructor(uint256 _totalSupply) {
        totalSupply=_totalSupply* (10**decimals);
        owner = msg.sender;
        //这个行为对吗？
        balanceOf[owner]=totalSupply;
        _paused=false;
    }

    modifier onlyOwner(){
        require(msg.sender==owner,"Just owner can operate");
        _;
    }
    receive() external payable { }

    //代币增发，只允许合约所有者才能调用
    function mint(address to,uint256 amount) public onlyOwner{
        require(to != address(0), "Mint to the zero address");
        require(amount>0,"please mint big than zero amount");
        totalSupply += amount;
        balanceOf[to] += amount;
    }

    //记录本代币额度授权给_spender（第三方合约）额度
    //这里操作流程如下：用户操作第三方合约--->（向钱包发起授权本代币请求）-->钱包展示该授权-->用户操作同意-->钱包向全网广播通知-->矿工收到后调用本方法完成记录
    //所以这里msg.sender为用户钱包(以太坊)地址，_spender：第三方合约地址
    function approve(address _spender,uint256 amount) public returns(bool success) {
        require(_spender!=address(0));
        allowance[msg.sender][_spender]=amount;
        emit EventApprove(msg.sender, _spender, amount, block.timestamp);
        return true;
    }   

    //代币转账，与approve对应，作用是提供给授权的第三方合约从本代币合约转指定数量代币到目标地址
    //流程流程如下：用户操作本代币转账-->检测是否授权-->已授权-->发起转账
    //这里的msg.sender 为第三方合约
    function transferFrom(address _from,address _to,uint256 amount)public returns(bool success)  {
        require(balanceOf[_from]>=amount,"error:not full balance");
        //检查授权额度
        require(allowance[_from][msg.sender]>=amount,"error:approve not full");
        //先把额度降低，避免不可控重入共计
        allowance[_from][msg.sender] = allowance[_from][msg.sender].sub(amount);
        //执行转账
        _transfer(_from, _to, amount);
        return true;
    }

    //转账，用户将自己的代币转账至指定账户
    //这个方法一般认为是安全的，不用nonReentrant防止重入，使用这个需要多花费2wgas
    function transfer(address _to,uint256 amount) public {
        require(_to != address(0),"vilidate address");
        require(amount>0,"transfer amount must big than zero");
        require(balanceOf[msg.sender]>amount,"not full balance");
        //执行转账
        _transfer(msg.sender,_to,amount);
        
    }

    //执行转账
    function _transfer(address _from,address _to,uint256 amount) internal returns(bool){
        require(!_paused,"WGT transfer had paused");
        require(_to!=_from,"error,do not transfer self by self");
        require(balanceOf[_from] >= amount,"error,current not enough balance");
        balanceOf[_from]-=amount;
        balanceOf[_to]+=amount;
        //通知
        emit EventTransferSuccess(_from,_to,amount,balanceOf[_from],block.timestamp);
        return true;
    }
    //销毁
    function burn(uint256 amount) public{
        require(balanceOf[msg.sender]>=amount,"Burn amount not full");
        balanceOf[msg.sender] -=amount;
        totalSupply-=amount;
        emit EventBurn(msg.sender,amount,block.timestamp);
    }

    //交易暂停  去中心化这个应该存在吗？
    function pause() public onlyOwner {
        _paused=true;
    }

    //交易启用
    function unpause() public onlyOwner{
        _paused=false;
    }
}