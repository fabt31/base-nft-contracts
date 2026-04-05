/**
 * NFT metadata utilities for Base L2
 * Helpers for generating, validating and pinning metadata
 */

/**
 * Generate standard ERC721 metadata object
 */
function buildMetadata({
  name,
  description,
  image,
  externalUrl = "",
  attributes = [],
  animationUrl = "",
}) {
  const metadata = {
    name,
    description,
    image,
    attributes,
  };
  if (externalUrl) metadata.external_url = externalUrl;
  if (animationUrl) metadata.animation_url = animationUrl;
  return metadata;
}

/**
 * Validate that a metadata object has required ERC721 fields
 */
function validateMetadata(metadata) {
  const required = ["name", "description", "image"];
  const missing = required.filter((k) => !metadata[k]);
  if (missing.length) throw new Error("Missing required fields: " + missing.join(", "));
  if (!Array.isArray(metadata.attributes)) throw new Error("attributes must be an array");
  return true;
}

/**
 * Build an attribute trait object
 */
function trait(traitType, value, displayType = null) {
  const t = { trait_type: traitType, value };
  if (displayType) t.display_type = displayType;
  return t;
}

/**
 * Convert IPFS CID to gateway URL
 */
function ipfsToGateway(ipfsUri, gateway = "https://ipfs.io/ipfs/") {
  if (ipfsUri.startsWith("ipfs://")) {
    return gateway + ipfsUri.slice(7);
  }
  return ipfsUri;
}

module.exports = { buildMetadata, validateMetadata, trait, ipfsToGateway };
