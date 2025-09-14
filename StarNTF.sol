// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

//星系NTF
contract StarNTF is ERC721,ERC721Enumerable,ERC721URIStorage,Ownable {
    //下一个可用tokenId
    uint256 private nextTokenId;
    //价格
    uint256 public constant MINT_PRICE = 0.001 ether;
    //基础URI 构建TOKENURI
    string private baseTokenURI;
    //映射地址--铸造NTF数量
    mapping (address=>uint256) public mintCounts;
    //每个地址最大铸造量
    uint256 public constant MAX_COUNT=3;

    constructor(string memory _uri) ERC721("StarNTF","SAR") Ownable(msg.sender) {
        nextTokenId=1;
        baseTokenURI=_uri;
    }

    //铸造--合约所有者才能调用
    function mint(address to,string memory uri) public onlyOwner{
        _safeMint(to,nextTokenId);
        _setTokenURI(nextTokenId,uri);
        nextTokenId+=1;
    }

    //公开花销铸造
    function publicMint(string memory uri) public payable {
        require(msg.value>=MINT_PRICE,"not sufficient payment");
        require(mintCounts[msg.sender]<=MAX_COUNT,"each one mint limited");
        _safeMint(msg.sender,nextTokenId);
        _setTokenURI(nextTokenId,uri);
        nextTokenId+=1;
    }
    //提取铸币的钱-合约所有者
    function withDraw() public onlyOwner{
        uint256 balance=address(this).balance;
        require(balance>0,"not sufficient balance");
        payable(owner()).transfer(balance);
    }
    //重写返回基础URI
     function _baseURI() internal  view virtual override returns(string memory){
        return baseTokenURI;
    }
    function setBaseURI(string memory uri) public onlyOwner{
        baseTokenURI=uri;
    }
    //下面这些都是多重继承 需要重写一下
    //重写ERC721，ERC721Enumerable _update
    function _update(address to,uint256 tokenId,address auth)internal override (ERC721,ERC721Enumerable) returns(address) {
        return super._update(to,tokenId,auth);
    }
    //重写
    function _increaseBalance(address account,uint128 value) internal override (ERC721,ERC721Enumerable){
        super._increaseBalance(account,value);
    }
    //重写
    function tokenURI(uint256 tokenId) public view override(ERC721,ERC721URIStorage)  returns (string memory){
        return super.tokenURI(tokenId);
    }
     //重写
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable, ERC721URIStorage) returns (bool){
        return super.supportsInterface(interfaceId);
    }


}