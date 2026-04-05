# NFT Development Guide for Base L2

## Overview

This guide explains how to deploy, mint, and manage NFTs on the Base L2 network using the contracts in this repository.

## Contract Selection

| Use Case | Contract |
|----------|----------|
| Basic collection | BaseERC721 |
| Multi-token (fungible + NFT) | BaseERC1155 |
| Whitelist/allowlist mint | BaseWhitelistNFT |
| Off-chain signing / gas-free listing | BaseLazyMint |
| NFT marketplace | BaseNFTMarket |
| Stake-to-earn | BaseNFTStaking |

## Metadata Standards

Base is EVM-compatible and follows OpenSea/Zora metadata standards.

### Example Metadata JSON

```json
{
  "name": "Base Genesis #1",
  "description": "First NFT in the Base Genesis collection",
  "image": "ipfs://QmYourImageCID/1.png",
  "external_url": "https://yourproject.xyz/token/1",
  "attributes": [
    { "trait_type": "Background", "value": "Blue" },
    { "trait_type": "Rarity", "value": "Common" },
    { "display_type": "number", "trait_type": "Generation", "value": 1 }
  ]
}
```

### Hosting Metadata

Options:
- **IPFS** (recommended): Use Pinata, NFT.Storage, or web3.storage
- **Arweave**: Permanent storage for immutable metadata
- **Centralized**: Acceptable for testnets, not recommended for mainnet

## Royalties (EIP-2981)

All contracts implement EIP-2981. Set royalty in basis points (BPS):
- 250 = 2.5%
- 500 = 5%
- 1000 = 10%

```solidity
// In constructor
_setDefaultRoyalty(royaltyRecipient, 500); // 5% royalty
```

## Whitelist Minting Flow

1. Collect allowlist addresses
2. Generate Merkle tree: `node scripts/generate_merkle.js addresses.json`
3. Set root on contract: `contract.setMerkleRoot(root)`
4. Users mint with proof from `merkle_output.json`

## Gas Optimization Tips

- Use Base Sepolia for testing (free ETH via faucet)
- Optimize with Hardhat coverage reports
- Batch mints save gas for large collections
- Use lazy minting to defer gas costs until sale

## Useful Resources

- [Base Docs](https://docs.base.org)
- [Basescan](https://basescan.org)
- [Base Bridge](https://bridge.base.org)
- [OpenSea on Base](https://opensea.io/explore-collections?category=base)
