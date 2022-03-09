// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import './CronosNFT.sol';

contract Auction {
    
    using SafeMath for uint256; 
    uint256 public platformFee;
    
    struct orderDetails {
        uint256 tokenId;
        address buyer;
        address seller;
        uint256 totalPrice;
        uint256 time;
    }
    
    mapping(address=>orderDetails[]) public orderLogs;
 
    address public contractOwner ;
    
    struct forBids{
        uint256 bidPrice;
        address bidder;
        uint256 tokenid;
    }

    forBids[] bidsArray;

    mapping(uint256 => forBids) public bidsmapping;
     
    CronosNFT public nft;
    IERC20 public CROToken;
     
    struct onBidItem{
        uint256 tokenId;
        address  owner;
        bool sold;
        bool onBid;
        uint256 timeOnBid;
        uint256  timeTillBidComplete;
        bool purchaseWithToken;
    }
    
    mapping( uint256 => onBidItem) public bidItems;
     
    
    constructor(address nftCreation, uint256 _platformFee, address payable _tokenAddress) {
        nft = CronosNFT(nftCreation);
        CROToken = IERC20(_tokenAddress);
        contractOwner = msg.sender;
        platformFee = _platformFee;
    }
        
    event PutTokenOnBid(uint256 tokenId,uint256 bidCompleteTime,address tokenOwner);
    event MakeBid(uint256 _bidprice,uint256 _tokenId,address bidder);
    event OnBidComplete(uint256 tokenId,address winner,uint256 _bidprice,address tokenOwner,orderDetails newOrder);
    event RemoveTokenFromBid(uint256 tokenId,address tokenOwner,bool isOnBid);
    event ChangeBidTokenStatus(uint256 tokenId,bool isSold);
        
    modifier checkTokenOwner(uint256 tokenId){
      require(nft.ownerOf(tokenId) == msg.sender,"YOU_DO_NOT_OWN_THIS_NFT");
        _;  
    }
    
    modifier tokenNotSoldAlready(uint256 tokenId){
        require(!bidItems[tokenId].sold,"NFT_ALREADY_SOLD");
        _;
    }
    
    function getBidsArray()public view returns(forBids[] memory){
        return bidsArray;
    }
    
     // Get the all order logs for perticualr buyer.
    function viewOrderLogs()external view returns(orderDetails[] memory ){
        uint length=orderLogs[msg.sender].length;
         orderDetails[] memory records = new orderDetails[](length);
        for (uint i=0; i<length; i++) {
            orderDetails storage orderDetail = orderLogs[msg.sender][i];
            records[i]=orderDetail;
        }
        return records;
    }
    
    function removeTokenFromBid(uint256 tokenId)external returns(bool){
        
        require(nft.balanceOf(msg.sender)!=0 ,"YOU_DO_NOT_OWN_THE_NFT");
        bidItems[tokenId].onBid=false;
        emit RemoveTokenFromBid(tokenId,msg.sender,false);
        //from node side=>nft.setApprovalForAll(address(this),false);
        return true;
    }
    
    function changeBidTokenStatus(uint256 tokenId,bool status) internal tokenNotSoldAlready(tokenId) returns(bool){
        require(bidItems[tokenId].owner == msg.sender, "ONLY_NFT_OWNER_CAN_UPDATE_STATUS");
        bidItems[tokenId].sold=status;
        emit ChangeBidTokenStatus(tokenId,status);
        return true;
    }
    
    function putTokenOnBid(uint256 tokenId,uint256 bidCompleteTime, bool _purchaseWithToken)external payable returns(bool){
     require(bidItems[tokenId].onBid == false,"TOKEN_ALREADY_ON_AUCTION");
     require(nft.ownerOf(tokenId)== msg.sender,"YOU_ARE_NOT_OWNER_OF_THE_NFT");
     require(nft.isApprovedForAll(nft.ownerOf(tokenId),address(this)),"NFT_NOT_APPROVED_FOR_TRANSFER");
        onBidItem memory newBidItem=onBidItem({
            tokenId:tokenId, 
            owner:msg.sender,
            sold:false,
            onBid:true,
            timeOnBid:block.timestamp,
            timeTillBidComplete:bidCompleteTime,
            purchaseWithToken: _purchaseWithToken
        });
        bidItems[tokenId]=newBidItem;
        emit PutTokenOnBid(tokenId,bidCompleteTime,msg.sender);
        return true;
    }
    
    function placeBidWithETH(uint256 _tokenId) public payable {
        require(!bidItems[_tokenId].purchaseWithToken, "CANNOT_BID_WITH_ETH_BUY_WITH_TOKEN");
        require(bidItems[_tokenId].owner!= msg.sender, "OWNER_OF_TOKEN_CANNOT_PLACE_A_BID");
        require(bidItems[_tokenId].timeTillBidComplete < block.timestamp, "BIDDING_PERIOD_COMPLETED");
        require(bidItems[_tokenId].timeOnBid != 0, "NFT_IS_NOT_BUYABLE");
        require(!bidItems[_tokenId].sold, "NFT_ALREADY_SOLD");
        require(bidItems[_tokenId].onBid == true, "NFT_IS_NOT_ON_BID");
        
        // Check if someone bidded previously
        uint256 prevBidPrice = bidsmapping[_tokenId].bidPrice;
        
        require(prevBidPrice < msg.value, "YOUR_BID_VALUE_IS_LESS_THAN_CURRENT_BID");
        
        // Refund Last Bidder
        address lastBidder = bidsmapping[_tokenId].bidder;
        payable(lastBidder).transfer(prevBidPrice);
        
        // Update Bid
        bidsmapping[_tokenId].bidPrice = msg.value;
        bidsmapping[_tokenId].bidder = msg.sender;
        bidsmapping[_tokenId].tokenid = _tokenId;
        
        
        forBids memory newBid=forBids({
            bidder : msg.sender,
            bidPrice: msg.value,
            tokenid:_tokenId
        });
        
        bidsArray.push(newBid);
        emit MakeBid(msg.value, _tokenId, msg.sender);
    }

    function placeBidWithToken(uint256 _tokenId, uint256 _bidTokenAmount) public payable {
        require(bidItems[_tokenId].purchaseWithToken, "CANNOT_BID_WITH_TOKEN_BID_WITH_BNB");
        require(bidItems[_tokenId].owner!= msg.sender, "OWNER_OF_TOKEN_CANNOT_PLACE_A_BID");
        require(bidItems[_tokenId].timeTillBidComplete < block.timestamp, "BIDDING_PERIOD_COMPLETED");
        require(bidItems[_tokenId].timeOnBid != 0, "NFT_IS_NOT_BUYABLE");
        require(!bidItems[_tokenId].sold, "NFT_ALREADY_SOLD");
        require(bidItems[_tokenId].onBid == true, "NFT_IS_NOT_ON_BID");
        
        // Check if someone bidded previously
        uint256 prevBidPrice = bidsmapping[_tokenId].bidPrice;
        
        require(prevBidPrice < _bidTokenAmount, "YOUR_BID_VALUE_IS_LESS_THAN_CURRENT_BID");

        require(CROToken.allowance(msg.sender, address(this)) >= _bidTokenAmount, "INSUFFICIENT_TOKEN_ALLOWANCE");
        require(CROToken.balanceOf(msg.sender) >= _bidTokenAmount, "INSUFFICIENT_TOKEN_BALANCE");

        // Refund Last Bidder if exist

        if(prevBidPrice > 0){
            address lastBidder = bidsmapping[_tokenId].bidder;
            CROToken.transfer(lastBidder, prevBidPrice);
        }

        // Transfer Bid Amount to Contract
        CROToken.transferFrom(msg.sender, address(this), _bidTokenAmount);

        // Update Bid
        bidsmapping[_tokenId].bidPrice = _bidTokenAmount;
        bidsmapping[_tokenId].bidder = msg.sender;
        bidsmapping[_tokenId].tokenid = _tokenId;
        
        forBids memory newBid=forBids({
            bidder : msg.sender,
            bidPrice: _bidTokenAmount,
            tokenid:_tokenId
        });
        
        bidsArray.push(newBid);
        emit MakeBid(_bidTokenAmount, _tokenId, msg.sender);
    }

    function onBidCompleteForETH(uint256 tokenId) public tokenNotSoldAlready(tokenId) payable returns(orderDetails memory){
        require(bidItems[tokenId].owner == msg.sender, "ONLY_NFT_OWNER_CAN_FINISH_AUCTION");
        require(!bidItems[tokenId].purchaseWithToken, "WRONG_CALL_USE_onBidCompleteForToken_FUNCTION");
        require((block.timestamp - bidItems[tokenId].timeTillBidComplete)>=0,"BIDDING_PERIOD_YET_TO_BE_COMPLETED");
        require(bidItems[tokenId].timeOnBid!=0,"NFT_IS_NOT_BUYABLE");
        require(!bidItems[tokenId].sold,"NFT_ALREADY_SOLD");
        require(bidItems[tokenId].onBid == true,"NFT_NOT_ON_AUCTION");
        require(nft.isApprovedForAll(bidItems[tokenId].owner,address(this)),"NFT_NOT_APPROVED_FOR_TRANSFER");

        orderDetails memory newOrder = orderDetails({
            tokenId: tokenId,
            buyer: bidsmapping[tokenId].bidder,
            seller: bidItems[tokenId].owner,
            totalPrice:bidsmapping[tokenId].bidPrice,
            time:block.timestamp
        });
        
        orderLogs[bidsmapping[tokenId].bidder].push(newOrder);
        changeBidTokenStatus(tokenId,true);  
        
        address creator = nft.getCreator(tokenId);

        uint256 bidPrice = bidsmapping[tokenId].bidPrice;
        uint256 amount = bidPrice.sub(bidPrice.mul(platformFee).div(100));
        payable(contractOwner).transfer(bidPrice.mul(platformFee).div(100));

        if(bidItems[tokenId].owner == creator){
            // Seller is Creator : No Royalty
            payable(creator).transfer(amount);
        }else{
            // Seller is Not Creator : Give Royalty
            uint256 royaltyAmount = amount.mul(nft.getTokenRoyaltyPercentage(tokenId)).div(100);
            amount = amount.sub(royaltyAmount);
            payable(bidItems[tokenId].owner).transfer(amount);
            payable(creator).transfer(royaltyAmount);
        }
        
        nft.safeTransferFrom(bidItems[tokenId].owner,bidsmapping[tokenId].bidder,tokenId);
        emit OnBidComplete(tokenId,bidsmapping[tokenId].bidder,bidsmapping[tokenId].bidPrice, bidItems[tokenId].owner,newOrder);
        return newOrder;
    }

    function onBidCompleteForToken(uint256 tokenId) public tokenNotSoldAlready(tokenId) payable returns(orderDetails memory){
        require(bidItems[tokenId].owner == msg.sender, "ONLY_NFT_OWNER_CAN_FINISH_AUCTION");
        require(bidItems[tokenId].purchaseWithToken, "WRONG_CALL_USE_onBidCompleteForETH_FUNCTION");
        require((block.timestamp - bidItems[tokenId].timeTillBidComplete)>=0,"BIDDING_PERIOD_YET_TO_BE_COMPLETED");
        require(bidItems[tokenId].timeOnBid!=0,"NFT_IS_NOT_BUYABLE");
        require(!bidItems[tokenId].sold,"NFT_ALREADY_SOLD");
        require(bidItems[tokenId].onBid == true,"NFT_NOT_ON_AUCTION");
        require(nft.isApprovedForAll(bidItems[tokenId].owner,address(this)),"NFT_NOT_APPROVED_FOR_TRANSFER");

        orderDetails memory newOrder = orderDetails({
            tokenId: tokenId,
            buyer: bidsmapping[tokenId].bidder,
            seller: bidItems[tokenId].owner,
            totalPrice:bidsmapping[tokenId].bidPrice,
            time:block.timestamp
        });
        
        orderLogs[bidsmapping[tokenId].bidder].push(newOrder);
        changeBidTokenStatus(tokenId,true);  
        
        uint256 bidPrice = bidsmapping[tokenId].bidPrice;
        
        address creator = nft.getCreator(tokenId);

        if(bidItems[tokenId].owner == creator){
            // Seller is Creator : No Royalty
            CROToken.transfer(bidItems[tokenId].owner, bidPrice);
        }else{
            // Seller is Not Creator : Give Royalty
            uint256 royaltyAmount = bidPrice.mul(nft.getTokenRoyaltyPercentage(tokenId)).div(100);
            bidPrice = bidPrice.sub(royaltyAmount);
            CROToken.transfer(bidItems[tokenId].owner, bidPrice);
            CROToken.transfer(creator, royaltyAmount);
        }
        
        nft.safeTransferFrom(bidItems[tokenId].owner,bidsmapping[tokenId].bidder,tokenId);
        emit OnBidComplete(tokenId,bidsmapping[tokenId].bidder,bidsmapping[tokenId].bidPrice, bidItems[tokenId].owner,newOrder);
        return newOrder;
    }
    
}