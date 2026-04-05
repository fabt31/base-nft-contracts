// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title BaseERC1155
 * @notice ERC1155 multi-token contract with EIP-2981 royalties.
 *         Supports both fungible and non-fungible token types.
 */
contract BaseERC1155 is ERC1155, ERC2981, Ownable {
    using Strings for uint256;

    string public name;
    string public symbol;

    // token ID => max supply (0 = unlimited)
    mapping(uint256 => uint256) public maxSupply;
    // token ID => current supply
    mapping(uint256 => uint256) public totalSupply;
    // token ID => mint price
    mapping(uint256 => uint256) public mintPrice;

    event TokenCreated(uint256 indexed id, uint256 maxSupply_, uint256 price);
    event TokenMinted(address indexed to, uint256 indexed id, uint256 amount);

    constructor(
        string memory name_,
        string memory symbol_,
        string memory uri_
    ) ERC1155(uri_) {
        name = name_;
        symbol = symbol_;
    }

    /// @notice Create a new token type
    function createToken(
        uint256 id,
        uint256 maxSupply_,
        uint256 price,
        address royaltyRecipient,
        uint96 royaltyBps
    ) external onlyOwner {
        require(maxSupply[id] == 0 && totalSupply[id] == 0, "BaseERC1155: token exists");
        maxSupply[id] = maxSupply_;
        mintPrice[id] = price;
        _setTokenRoyalty(id, royaltyRecipient, royaltyBps);
        emit TokenCreated(id, maxSupply_, price);
    }

    /// @notice Public mint
    function mint(uint256 id, uint256 amount) external payable {
        require(msg.value >= mintPrice[id] * amount, "BaseERC1155: insufficient payment");
        require(
            maxSupply[id] == 0 || totalSupply[id] + amount <= maxSupply[id],
            "BaseERC1155: exceeds max supply"
        );
        totalSupply[id] += amount;
        _mint(msg.sender, id, amount, "");
        emit TokenMinted(msg.sender, id, amount);
    }

    /// @notice Owner batch mint
    function ownerMintBatch(
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external onlyOwner {
        _mintBatch(to, ids, amounts, "");
    }

    function setURI(string calldata newURI) external onlyOwner {
        _setURI(newURI);
    }

    function withdraw() external onlyOwner {
        (bool ok,) = owner().call{value: address(this).balance}("");
        require(ok, "BaseERC1155: withdraw failed");
    }

    function supportsInterface(bytes4 interfaceId)
        public view override(ERC1155, ERC2981) returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
