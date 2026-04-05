// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title BaseNFTStaking
 * @notice Stake ERC721 NFTs to earn ERC20 reward tokens.
 *         Rewards accrue per NFT per day.
 */
contract BaseNFTStaking is IERC721Receiver, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    IERC721 public immutable nftContract;
    IERC20 public immutable rewardToken;

    uint256 public rewardPerNFTPerDay;

    struct StakeInfo {
        address owner;
        uint256 stakedAt;
        uint256 rewardDebt;
    }

    mapping(uint256 => StakeInfo) public stakes;
    mapping(address => uint256[]) public stakedTokenIds;

    event NFTStaked(address indexed user, uint256 indexed tokenId);
    event NFTUnstaked(address indexed user, uint256 indexed tokenId, uint256 rewards);
    event RewardsClaimed(address indexed user, uint256 rewards);

    constructor(address _nft, address _rewardToken, uint256 _rewardPerNFTPerDay) {
        nftContract = IERC721(_nft);
        rewardToken = IERC20(_rewardToken);
        rewardPerNFTPerDay = _rewardPerNFTPerDay;
    }

    function stake(uint256 tokenId) external nonReentrant {
        require(nftContract.ownerOf(tokenId) == msg.sender, "BaseNFTStaking: not token owner");
        nftContract.safeTransferFrom(msg.sender, address(this), tokenId);
        stakes[tokenId] = StakeInfo({owner: msg.sender, stakedAt: block.timestamp, rewardDebt: 0});
        stakedTokenIds[msg.sender].push(tokenId);
        emit NFTStaked(msg.sender, tokenId);
    }

    function unstake(uint256 tokenId) external nonReentrant {
        StakeInfo storage info = stakes[tokenId];
        require(info.owner == msg.sender, "BaseNFTStaking: not staker");

        uint256 rewards = _pendingRewards(tokenId);
        delete stakes[tokenId];
        _removeFromArray(msg.sender, tokenId);

        nftContract.safeTransferFrom(address(this), msg.sender, tokenId);
        if (rewards > 0) rewardToken.safeTransfer(msg.sender, rewards);

        emit NFTUnstaked(msg.sender, tokenId, rewards);
    }

    function claimRewards(uint256 tokenId) external nonReentrant {
        StakeInfo storage info = stakes[tokenId];
        require(info.owner == msg.sender, "BaseNFTStaking: not staker");
        uint256 rewards = _pendingRewards(tokenId);
        require(rewards > 0, "BaseNFTStaking: no rewards");
        info.stakedAt = block.timestamp;
        rewardToken.safeTransfer(msg.sender, rewards);
        emit RewardsClaimed(msg.sender, rewards);
    }

    function pendingRewards(uint256 tokenId) external view returns (uint256) {
        return _pendingRewards(tokenId);
    }

    function _pendingRewards(uint256 tokenId) internal view returns (uint256) {
        StakeInfo storage info = stakes[tokenId];
        if (info.owner == address(0)) return 0;
        uint256 elapsed = block.timestamp - info.stakedAt;
        return (elapsed * rewardPerNFTPerDay) / 1 days;
    }

    function _removeFromArray(address user, uint256 tokenId) internal {
        uint256[] storage arr = stakedTokenIds[user];
        for (uint256 i = 0; i < arr.length; i++) {
            if (arr[i] == tokenId) { arr[i] = arr[arr.length - 1]; arr.pop(); break; }
        }
    }

    function onERC721Received(address, address, uint256, bytes calldata)
        external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function setRewardRate(uint256 rate) external onlyOwner {
        rewardPerNFTPerDay = rate;
    }
}
