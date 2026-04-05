// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title BaseERC721
 * @notice ERC721 with URI storage, EIP-2981 royalties, and pausable minting.
 */
contract BaseERC721 is ERC721URIStorage, ERC2981, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;

    uint256 public constant MAX_SUPPLY = 10000;
    uint256 public mintPrice = 0.001 ether;
    bool public mintingActive = false;
    string public baseTokenURI;

    event Minted(address indexed to, uint256 indexed tokenId, string tokenURI);
    event MintingToggled(bool active);
    event MintPriceUpdated(uint256 newPrice);

    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        address royaltyRecipient,
        uint96 royaltyBps
    ) ERC721(name_, symbol_) {
        baseTokenURI = baseURI_;
        _setDefaultRoyalty(royaltyRecipient, royaltyBps);
    }

    function mint(string memory tokenURI_) external payable {
        require(mintingActive, "BaseERC721: minting not active");
        require(msg.value >= mintPrice, "BaseERC721: insufficient payment");
        require(_tokenIds.current() < MAX_SUPPLY, "BaseERC721: max supply reached");

        _tokenIds.increment();
        uint256 newId = _tokenIds.current();
        _safeMint(msg.sender, newId);
        _setTokenURI(newId, tokenURI_);

        emit Minted(msg.sender, newId, tokenURI_);
    }

    function ownerMint(address to, string memory tokenURI_) external onlyOwner {
        require(_tokenIds.current() < MAX_SUPPLY, "BaseERC721: max supply reached");
        _tokenIds.increment();
        uint256 newId = _tokenIds.current();
        _safeMint(to, newId);
        _setTokenURI(newId, tokenURI_);
        emit Minted(to, newId, tokenURI_);
    }

    function toggleMinting() external onlyOwner {
        mintingActive = !mintingActive;
        emit MintingToggled(mintingActive);
    }

    function setMintPrice(uint256 price) external onlyOwner {
        mintPrice = price;
        emit MintPriceUpdated(price);
    }

    function setDefaultRoyalty(address recipient, uint96 bps) external onlyOwner {
        _setDefaultRoyalty(recipient, bps);
    }

    function withdraw() external onlyOwner {
        (bool ok,) = owner().call{value: address(this).balance}("");
        require(ok, "BaseERC721: withdraw failed");
    }

    function totalSupply() public view returns (uint256) {
        return _tokenIds.current();
    }

    function supportsInterface(bytes4 interfaceId)
        public view override(ERC721URIStorage, ERC2981) returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
