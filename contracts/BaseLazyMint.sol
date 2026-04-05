// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title BaseLazyMint
 * @notice Lazy minting: NFTs are only minted when a buyer redeems a signed voucher.
 *         The creator signs a voucher off-chain; the buyer submits it on-chain with payment.
 */
contract BaseLazyMint is ERC721URIStorage, Ownable {
    using ECDSA for bytes32;
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;

    struct Voucher {
        uint256 minPrice;
        string tokenURI;
        bytes signature;
    }

    address public signer;

    event VoucherRedeemed(address indexed buyer, uint256 indexed tokenId, uint256 price);

    constructor(string memory name_, string memory symbol_, address signer_)
        ERC721(name_, symbol_)
    {
        signer = signer_;
    }

    function redeem(address buyer, Voucher calldata voucher) external payable returns (uint256) {
        require(msg.value >= voucher.minPrice, "BaseLazyMint: insufficient payment");

        address recovered = _recoverSigner(voucher);
        require(recovered == signer, "BaseLazyMint: invalid signature");

        _tokenIds.increment();
        uint256 newId = _tokenIds.current();
        _safeMint(buyer, newId);
        _setTokenURI(newId, voucher.tokenURI);

        payable(owner()).transfer(msg.value);
        emit VoucherRedeemed(buyer, newId, msg.value);
        return newId;
    }

    function _recoverSigner(Voucher calldata voucher) internal pure returns (address) {
        bytes32 hash = keccak256(abi.encode(voucher.minPrice, voucher.tokenURI));
        bytes32 ethSignedHash = hash.toEthSignedMessageHash();
        return ethSignedHash.recover(voucher.signature);
    }

    function setSigner(address newSigner) external onlyOwner {
        signer = newSigner;
    }

    function totalSupply() public view returns (uint256) { return _tokenIds.current(); }
}
