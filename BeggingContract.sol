// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

//作业三-捐赠合约
contract BeggingContract is Ownable {
    //记录
    mapping(address=>uint256) public records;
    //捐赠余额 eth
    uint256 public totalBalance;

    constructor() Ownable(msg.sender){

    }
    event EventDonateSuccess(address from,uint256 value,uint256 timestamp);
    event EventWithDraw(address user,uint256 amount,uint256 timestamp);
    receive() external payable { }

    //捐赠
    function donate() public payable {
        require(msg.value>0,"insufficient payment");
        records[msg.sender]+=msg.value;
        totalBalance += msg.value;
        emit EventDonateSuccess(msg.sender,msg.value,block.timestamp);
    }

    //查询捐赠记录
    function getDonation(address from) public view returns(uint256 amount){
        return records[from];
    }

    //取款---只有合约所有人才可
    function withDraw() public onlyOwner{
        uint256 balance=address(this).balance;
        require(balance>0,"not sufficient balance");
        payable(msg.sender).transfer(balance);
        // (bool success,) =msg.sender.call{value:balance}();
        totalBalance=0;
        emit EventWithDraw(msg.sender,balance,block.timestamp);
    }

}