// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";

/**
 * @title BaseNFTMarket
 * @notice Decentralized NFT marketplace with EIP-2981 royalty support.
 *         Sellers list NFTs at fixed price; buyers pay and receive the NFT.
 */
contract BaseNFTMarket is ReentrancyGuard, Ownable {
    struct Listing {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 price;
        bool active;
    }

    uint256 private _nextListingId;
    mapping(uint256 => Listing) public listings;

    uint256 public platformFeeBps = 250; // 2.5%

    event Listed(uint256 indexed listingId, address indexed seller, address nftContract, uint256 tokenId, uint256 price);
    event Sold(uint256 indexed listingId, address indexed buyer, uint256 price);
    event Cancelled(uint256 indexed listingId);

    function listNFT(address nftContract, uint256 tokenId, uint256 price) external returns (uint256 listingId) {
        require(price > 0, "BaseNFTMarket: price must be > 0");
        IERC721 nft = IERC721(nftContract);
        require(nft.ownerOf(tokenId) == msg.sender, "BaseNFTMarket: not owner");
        require(nft.isApprovedForAll(msg.sender, address(this)) ||
            nft.getApproved(tokenId) == address(this), "BaseNFTMarket: not approved");

        listingId = _nextListingId++;
        listings[listingId] = Listing({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            price: price,
            active: true
        });
        emit Listed(listingId, msg.sender, nftContract, tokenId, price);
    }

    function buyNFT(uint256 listingId) external payable nonReentrant {
        Listing storage listing = listings[listingId];
        require(listing.active, "BaseNFTMarket: not active");
        require(msg.value >= listing.price, "BaseNFTMarket: insufficient payment");

        listing.active = false;

        uint256 platformFee = (listing.price * platformFeeBps) / 10000;
        uint256 remaining = listing.price - platformFee;

        // Pay royalties if supported
        try IERC2981(listing.nftContract).royaltyInfo(listing.tokenId, remaining)
            returns (address royaltyReceiver, uint256 royaltyAmount) {
            if (royaltyAmount > 0 && royaltyReceiver != address(0)) {
                remaining -= royaltyAmount;
                payable(royaltyReceiver).transfer(royaltyAmount);
            }
        } catch {}

        payable(listing.seller).transfer(remaining);

        IERC721(listing.nftContract).safeTransferFrom(listing.seller, msg.sender, listing.tokenId);
        emit Sold(listingId, msg.sender, listing.price);
    }

    function cancelListing(uint256 listingId) external {
        Listing storage listing = listings[listingId];
        require(listing.seller == msg.sender || msg.sender == owner(), "BaseNFTMarket: unauthorized");
        require(listing.active, "BaseNFTMarket: not active");
        listing.active = false;
        emit Cancelled(listingId);
    }

    function setPlatformFee(uint256 feeBps) external onlyOwner {
        require(feeBps <= 1000, "BaseNFTMarket: fee too high");
        platformFeeBps = feeBps;
    }

    function withdrawFees() external onlyOwner {
        (bool ok,) = owner().call{value: address(this).balance}("");
        require(ok, "BaseNFTMarket: withdraw failed");
    }
}
