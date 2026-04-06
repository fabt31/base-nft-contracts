// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title BaseNFTAuction
 * @notice English auction contract for ERC721 NFTs on Base L2.
 * Supports EIP-2981 royalties paid automatically on settlement.
 */
contract BaseNFTAuction is IERC721Receiver, Ownable, ReentrancyGuard {

    struct Auction {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 startPrice;    // minimum bid in wei
        uint256 reservePrice;  // minimum acceptable final bid (0 = no reserve)
        uint256 highestBid;
        address highestBidder;
        uint256 endTime;
        bool settled;
    }

    uint256 public nextAuctionId;
    uint256 public platformFeeBps = 250; // 2.5%
    uint256 public constant BPS_BASE = 10_000;
    uint256 public constant MIN_DURATION = 1 hours;
    uint256 public constant MAX_DURATION = 30 days;
    uint256 public constant BID_EXTENSION = 10 minutes;

    mapping(uint256 => Auction) public auctions;
    mapping(address => uint256) public pendingWithdrawals;

    event AuctionCreated(uint256 indexed auctionId, address indexed seller, address nftContract, uint256 tokenId, uint256 endTime);
    event BidPlaced(uint256 indexed auctionId, address indexed bidder, uint256 amount);
    event AuctionSettled(uint256 indexed auctionId, address indexed winner, uint256 amount);
    event AuctionCancelled(uint256 indexed auctionId);

    constructor() Ownable(msg.sender) {}

    function createAuction(
        address nftContract,
        uint256 tokenId,
        uint256 startPrice,
        uint256 reservePrice,
        uint256 duration
    ) external returns (uint256 auctionId) {
        require(duration >= MIN_DURATION && duration <= MAX_DURATION, "Invalid duration");
        require(startPrice > 0, "Start price must be > 0");

        IERC721(nftContract).safeTransferFrom(msg.sender, address(this), tokenId);

        auctionId = nextAuctionId++;
        auctions[auctionId] = Auction({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            startPrice: startPrice,
            reservePrice: reservePrice,
            highestBid: 0,
            highestBidder: address(0),
            endTime: block.timestamp + duration,
            settled: false
        });

        emit AuctionCreated(auctionId, msg.sender, nftContract, tokenId, block.timestamp + duration);
    }

    function bid(uint256 auctionId) external payable nonReentrant {
        Auction storage a = auctions[auctionId];
        require(block.timestamp < a.endTime, "Auction ended");
        require(!a.settled, "Already settled");
        require(msg.value >= a.startPrice, "Below start price");
        require(msg.value > a.highestBid, "Bid too low");

        if (a.highestBidder != address(0)) {
            pendingWithdrawals[a.highestBidder] += a.highestBid;
        }

        a.highestBid = msg.value;
        a.highestBidder = msg.sender;

        // Extend auction if bid is in last 10 minutes
        if (a.endTime - block.timestamp < BID_EXTENSION) {
            a.endTime = block.timestamp + BID_EXTENSION;
        }

        emit BidPlaced(auctionId, msg.sender, msg.value);
    }

    function settleAuction(uint256 auctionId) external nonReentrant {
        Auction storage a = auctions[auctionId];
        require(block.timestamp >= a.endTime, "Auction not ended");
        require(!a.settled, "Already settled");
        require(a.highestBid >= a.reservePrice || a.reservePrice == 0, "Reserve not met");

        a.settled = true;

        if (a.highestBidder == address(0)) {
            IERC721(a.nftContract).safeTransferFrom(address(this), a.seller, a.tokenId);
            emit AuctionCancelled(auctionId);
            return;
        }

        uint256 platformFee = (a.highestBid * platformFeeBps) / BPS_BASE;
        uint256 remaining = a.highestBid - platformFee;

        // Pay EIP-2981 royalties
        try IERC2981(a.nftContract).royaltyInfo(a.tokenId, remaining) returns (address royaltyReceiver, uint256 royaltyAmount) {
            if (royaltyAmount > 0 && royaltyReceiver != address(0)) {
                remaining -= royaltyAmount;
                payable(royaltyReceiver).transfer(royaltyAmount);
            }
        } catch {}

        payable(a.seller).transfer(remaining);
        payable(owner()).transfer(platformFee);
        IERC721(a.nftContract).safeTransferFrom(address(this), a.highestBidder, a.tokenId);

        emit AuctionSettled(auctionId, a.highestBidder, a.highestBid);
    }

    function withdraw() external nonReentrant {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "Nothing to withdraw");
        pendingWithdrawals[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

    function setplatformFeeBps(uint256 bps) external onlyOwner {
        require(bps <= 1000, "Max 10%");
        platformFeeBps = bps;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
