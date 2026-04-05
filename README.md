# base-nft-contracts

NFT smart contracts for the Base L2 ecosystem. Includes ERC721, ERC1155, and advanced NFT patterns.

## Contracts

| Contract | Description |
|----------|-------------|
| `BaseERC721.sol` | Basic ERC721 with URI storage and royalties |
| `BaseERC1155.sol` | ERC1155 multi-token standard |
| `BaseLazyMint.sol` | Lazy minting with signature verification |
| `BaseWhitelistNFT.sol` | Whitelist-based minting with Merkle proofs |
| `BaseGenerativeNFT.sol` | On-chain generative art NFT |
| `BaseNFTMarket.sol` | Simple NFT marketplace with royalty support |
| `BaseNFTStaking.sol` | Stake NFTs to earn ERC20 rewards |

## Network

- **Base Mainnet** (chainId: 8453)
- **Base Sepolia** (chainId: 84532)

## Setup

```bash
npm install
cp .env.example .env
npm run compile
npm test
```

## Deploy

```bash
npm run deploy:sepolia   # testnet
npm run deploy:mainnet   # mainnet
```

## Standards

All contracts follow EIP-2981 for royalties and are compatible with OpenSea and other Base NFT marketplaces.

> Educational / experimental — not audited. Use at your own risk.
