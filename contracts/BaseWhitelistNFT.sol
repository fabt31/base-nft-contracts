// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title BaseWhitelistNFT
 * @notice ERC721 with Merkle-proof-based whitelist minting.
 *         Phase 1: whitelist only. Phase 2: public mint.
 */
contract BaseWhitelistNFT is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;

    bytes32 public merkleRoot;
    uint256 public constant MAX_SUPPLY = 5000;
    uint256 public whitelistMintPrice = 0.0005 ether;
    uint256 public publicMintPrice = 0.001 ether;
    bool public whitelistActive = false;
    bool public publicActive = false;
    string public baseTokenURI;

    // Track whitelist claims per address
    mapping(address => bool) public whitelistClaimed;

    event WhitelistMint(address indexed user, uint256 indexed tokenId);
    event PublicMint(address indexed user, uint256 indexed tokenId);

    constructor(string memory name_, string memory symbol_, string memory baseURI_)
        ERC721(name_, symbol_)
    {
        baseTokenURI = baseURI_;
    }

    function setMerkleRoot(bytes32 root) external onlyOwner {
        merkleRoot = root;
    }

    function setWhitelistActive(bool active) external onlyOwner {
        whitelistActive = active;
    }

    function setPublicActive(bool active) external onlyOwner {
        publicActive = active;
    }

    function whitelistMint(bytes32[] calldata proof) external payable {
        require(whitelistActive, "BaseWhitelistNFT: whitelist not active");
        require(!whitelistClaimed[msg.sender], "BaseWhitelistNFT: already claimed");
        require(msg.value >= whitelistMintPrice, "BaseWhitelistNFT: insufficient payment");
        require(_tokenIds.current() < MAX_SUPPLY, "BaseWhitelistNFT: sold out");

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(proof, merkleRoot, leaf), "BaseWhitelistNFT: invalid proof");

        whitelistClaimed[msg.sender] = true;
        _mintTo(msg.sender);
        emit WhitelistMint(msg.sender, _tokenIds.current());
    }

    function publicMint(string memory tokenURI_) external payable {
        require(publicActive, "BaseWhitelistNFT: public mint not active");
        require(msg.value >= publicMintPrice, "BaseWhitelistNFT: insufficient payment");
        require(_tokenIds.current() < MAX_SUPPLY, "BaseWhitelistNFT: sold out");

        _mintTo(msg.sender);
        _setTokenURI(_tokenIds.current(), tokenURI_);
        emit PublicMint(msg.sender, _tokenIds.current());
    }

    function _mintTo(address to) internal {
        _tokenIds.increment();
        _safeMint(to, _tokenIds.current());
    }

    function withdraw() external onlyOwner {
        (bool ok,) = owner().call{value: address(this).balance}("");
        require(ok, "withdraw failed");
    }

    function totalSupply() public view returns (uint256) { return _tokenIds.current(); }
}
