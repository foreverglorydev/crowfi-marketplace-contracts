
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
 
import "@openzeppelin/contracts/access/Ownable.sol"; 
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";


contract CronosNFT is ERC721, ERC721URIStorage, ERC721Enumerable{
    
    using Counters for Counters.Counter;
    using SafeMath for uint256;

    Counters.Counter public _tokenIds;

    uint256 public NFTCreationFees;
    address public owner;

    mapping(uint256 => uint256) public royaltyPercentage;
    mapping(uint256 => address) public creators;

    constructor(uint256 _NFTCreationFees) ERC721("", "") {
        NFTCreationFees = _NFTCreationFees;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(owner == msg.sender, "#CronosNFT: ONLY_OWNER_CAN_ACCESS_THIS_FUNCTION");
        _;
    }

    // Input fees in wei
    function updateMintingFees(uint256 _newNFTCreationFees) public onlyOwner() {
        NFTCreationFees = _newNFTCreationFees;

    }

    function createNFT(string memory _tokenURI, uint256 _royaltyPercentage)
        public payable
        returns (uint256)
    {
        require(msg.value == NFTCreationFees, "#CronosNFT : INVALID_NFT_CREATION_FEES_SENT");
        require(_royaltyPercentage <= 5, "#CronosNFT : ROYALTY_PERCENTAGE_SHOULD_BE_LESS_THAN_5");
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        
        creators[newTokenId] = msg.sender;
        _mint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, _tokenURI);
        royaltyPercentage[newTokenId] = _royaltyPercentage;
        //Collect NFT Creation Fees
        payable(owner).transfer(msg.value);
        return newTokenId;
    }

    function getCreator(uint256 tokenId) view public returns(address){
        return creators[tokenId];
    }

    function getTokenRoyaltyPercentage(uint256 tokenId) view public returns(uint256){
        return royaltyPercentage[tokenId];
    }

    function getTokenIds(address _owner) public view returns (uint[] memory) {
        uint[] memory _tokensOfOwner = new uint[](balanceOf(_owner));
        uint i;

        for (i=0;i<ERC721.balanceOf(_owner);i++){
            _tokensOfOwner[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return (_tokensOfOwner);
    }
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {

    }
    
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        // address owner = ERC721.ownerOf(tokenId);

        // _beforeTokenTransfer(owner, address(0), tokenId);

        // // Clear approvals
        // _approve(address(0), tokenId);

        // _balances[owner] -= 1;
        // delete _owners[tokenId];

        // emit Transfer(owner, address(0), tokenId);
    }
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId)) : "";
    }
}