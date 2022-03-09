 
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
 
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/utils/Context.sol';
import "@openzeppelin/contracts/access/Ownable.sol"; 
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import './CronosNFT.sol';

pragma solidity ^0.8.4;


contract MarketPlace{
    
    using SafeMath for uint256; 
    
    IERC20 public CROToken;

    uint256 public platformFee;
    uint256 public saleItemsCount;

    struct orderDetails {
        uint256 tokenId;
        address buyer;
        address seller;
        uint256 totalPrice;
        uint256 time;
    }

    mapping(address=>orderDetails[]) public orderLogs;

    address public contractOwner ;

    struct onSaleItem{
        uint256 tokenId;
        address owner;
        bool sold;
        bool onSale;
        uint256 timeOnsale;
        uint256 price;
        bool purchaseWithToken;
    }
    
    mapping(uint256=>onSaleItem) public saleItems; 
    mapping(uint256 => uint256) public tokensOnSale;

    CronosNFT public nft;
    
    constructor(address nftCreation, uint256 _platformFee, address payable _tokenAddress) {
        nft = CronosNFT(nftCreation);
        CROToken = IERC20(_tokenAddress);
        platformFee = _platformFee;
        contractOwner = msg.sender;
    }
        
    event PutTokenOnSale(uint256 tokenId,uint256 price,address tokenOwner, bool purchaseWithToken);
    event BuyToken(uint256 tokenId,address buyer,uint256 tokenPrice,address tokenOwner,orderDetails newOrder);
    event RemoveTokenFromSale(uint256 tokenId,address tokenOwner,bool isOnSale);
    event ChangeSaleTokenStatus(uint256 tokenId,bool isSold);
        
    // RECHECK    
    modifier checkTokenOwner(){
      require(nft.balanceOf(msg.sender)!=0,'You donot own the token');
        _;  
    }
    
    modifier onlyOwner(){
        require(msg.sender == contractOwner,"ONLY_OWNER_CAN_CALL_THIS_FUNCTION");
        _;
    }
    
    modifier tokenNotSoldAlready(uint256 tokenId){
        require(!saleItems[tokenId].sold,"NFT_ALREADY_SOLD");
        _;
    }
    
    function setPlatfromFee(uint256 _platformFee) public onlyOwner() {
        platformFee = _platformFee;
    }
    
    function removeTokenFromSale(uint256 tokenId)external returns(bool){
        require(nft.balanceOf(msg.sender)!=0 ,"YOU_DO_NOT_OWN_THE_NFT");
        saleItems[tokenId].onSale=false;
        emit RemoveTokenFromSale(tokenId,msg.sender,false);
        //from node side =>nft.setApprovalForAll(address(this),false);
        return true;     
    }
    
    function changeSaleTokenStatus(uint256 tokenId,bool status)internal tokenNotSoldAlready(tokenId) returns(bool){
        require(nft.balanceOf(msg.sender)!=0 ,"YOU_DO_NOT_OWN_THIS_NFT");
        saleItems[tokenId].sold = status;
        emit ChangeSaleTokenStatus(tokenId,status);
        return true;
    }
    
    // amount: price of nft 
    function putTokenOnSale(uint256 _tokenId, uint256 _amount, bool _purchaseWithToken)external  checkTokenOwner() payable returns(bool){
        require(saleItems[_tokenId].onSale == false,"TOKEN_ALREADY_ON_SALE");
        require(nft.ownerOf(_tokenId)== msg.sender,"YOU_ARE_NOT_OWNER_OF_THE_NFT");
        require(nft.isApprovedForAll(nft.ownerOf(_tokenId),address(this)),"NFT_NOT_APPROVED_FOR_TRANSFER");

       //node side => nft.setApprovalForAll(msg.sender,true);
        onSaleItem memory newItem=onSaleItem({
            tokenId:_tokenId, 
            owner:msg.sender,
            sold:false,
            onSale:true,
            timeOnsale:block.timestamp,
            price:_amount,
            purchaseWithToken:_purchaseWithToken
        });
        saleItems[_tokenId]=newItem;
        saleItemsCount = saleItemsCount.add(1);
        tokensOnSale[saleItemsCount] = _tokenId;
        emit PutTokenOnSale(_tokenId,_amount,msg.sender,_purchaseWithToken);
        return true;
    }
    
    function buyNFTWithETH(uint256 tokenId, address buyer)external payable tokenNotSoldAlready(tokenId) returns(orderDetails memory) {
         // check wether tokens is in buyable list or not!
        require(!saleItems[tokenId].purchaseWithToken, "CANNOT_BUY_WITH_ETH_BUY_WITH_TOKEN");
        require(saleItems[tokenId].timeOnsale!=0,"NFT_IS_NOT_BUYABLE");
        require(!saleItems[tokenId].sold,"NFT_ALREADY_SOLD");
        require(saleItems[tokenId].onSale == true,"NFT_NOT_ON_SALE");
        require(nft.isApprovedForAll(saleItems[tokenId].owner,address(this)),"NFT_NOT_APPROVED_FOR_TRANSFER");
        
        orderDetails memory newOrder = orderDetails({
                tokenId: tokenId,
                buyer: buyer,
                seller: saleItems[tokenId].owner,
                totalPrice:saleItems[tokenId].price,
                time:block.timestamp
        });
        orderLogs[buyer].push(newOrder);
        
        require(msg.value == saleItems[tokenId].price, "INSUFFICIENT_ETH_AMOUNT");
                
        // transfer ethers from buyers account to sellers account 
        address creator = nft.getCreator(tokenId);
        uint256 amount = msg.value.sub(msg.value.mul(platformFee).div(100));
        payable(contractOwner).transfer(msg.value.mul(platformFee).div(100));
        
        if(saleItems[tokenId].owner == creator){
            // Seller is Creator : No Royalty
            payable(creator).transfer(amount);
        }else{
            // Seller is Not Creator : Give Royalty
            uint256 royaltyAmount = amount.mul(nft.getTokenRoyaltyPercentage(tokenId)).div(100);
            amount = amount.sub(royaltyAmount);
            payable(saleItems[tokenId].owner).transfer(amount);
            payable(creator).transfer(royaltyAmount);
        }

        nft.safeTransferFrom(saleItems[tokenId].owner,buyer,tokenId);
        
        // remove token from saleItems list
        changeSaleTokenStatus(tokenId,true);
        emit BuyToken(tokenId,buyer,saleItems[tokenId].price,saleItems[tokenId].owner,newOrder);
        return newOrder;
    }

    function buyNFTWithToken(uint256 tokenId, address buyer)external payable tokenNotSoldAlready(tokenId) returns(orderDetails memory) {
         // check whether tokens is in buyable list or not!
        require(saleItems[tokenId].purchaseWithToken, "CANNOT_BUY_WITH_TOKEN_BUY_WITH_BNB");
        require(saleItems[tokenId].timeOnsale!=0,"NFT_IS_NOT_BUYABLE");
        require(!saleItems[tokenId].sold,"NFT_ALREADY_SOLD");
        require(saleItems[tokenId].onSale == true,"NFT_NOT_ON_SALE");
        require(nft.isApprovedForAll(saleItems[tokenId].owner,address(this)),"NFT_NOT_APPROVED_FOR_TRANSFER");
        

        orderDetails memory newOrder = orderDetails({
                tokenId: tokenId,
                buyer: buyer,
                seller: saleItems[tokenId].owner,
                totalPrice:saleItems[tokenId].price,
                time:block.timestamp
        });
        orderLogs[buyer].push(newOrder);
        
        require(CROToken.allowance(msg.sender, address(this)) >= saleItems[tokenId].price, "INSUFFICIENT_TOKEN_ALLOWANCE");
        require(CROToken.balanceOf(msg.sender) >= saleItems[tokenId].price, "INSUFFICIENT_TOKEN_BALANCE");
                
        // transfer tokens from buyers account to owner seller's account
        address creator = nft.getCreator(tokenId);
        uint256 amount = saleItems[tokenId].price.mul(8); // CRO Token Decimals : 8
        
        if(saleItems[tokenId].owner == creator){
            // Seller is Creator : No Royalty
             CROToken.transferFrom(msg.sender,creator, amount);
        }else{
            // Seller is Not Creator : Give Royalty
            uint256 royaltyAmount = amount.mul(nft.getTokenRoyaltyPercentage(tokenId)).div(100);
            amount = amount.sub(royaltyAmount);
            CROToken.transferFrom(msg.sender, saleItems[tokenId].owner, amount);
            CROToken.transferFrom(msg.sender, creator, royaltyAmount);
        }

        nft.safeTransferFrom(saleItems[tokenId].owner,buyer,tokenId);
        
        // remove token from saleItems list
        changeSaleTokenStatus(tokenId,true);
        emit BuyToken(tokenId,buyer,saleItems[tokenId].price,saleItems[tokenId].owner,newOrder);
        return newOrder;
    }
    
}