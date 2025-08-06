// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

contract Collateral is ERC721, ERC721Burnable {
    using Strings for uint256;

    uint256 public nextTokenId;
    address public admin;

    struct BondInfo {
        string issuer;           // ex: "Republic of Korea"
        uint256 faceValue;       // in smallest unit, e.g., 원 단위
        uint256 couponRateBPS;   // basis points, e.g., 253 for 2.53%
        uint256 issueDate;       // unix timestamp
        uint256 maturityDate;    // unix timestamp
        string couponFreq;       // e.g., "Annual", "Semi-Annual", "None"
        string description;      // optional free-form
    }

    // tokenId => bond info
    mapping(uint256 => BondInfo) public bondInfo;

    event BondMinted(uint256 indexed tokenId, address to);
    event BondInfoUpdated(uint256 indexed tokenId);

    constructor() ERC721("Won Repo 07", "WRP07") {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    /// @notice Mint a new NFT with associated bond metadata
    function mintWithBond(
        address to,
        string calldata issuer,
        uint256 faceValue,
        uint256 couponRateBPS,
        uint256 issueDate,
        uint256 maturityDate,
        string calldata couponFreq,
        string calldata description
    ) external onlyAdmin {
        uint256 tid = nextTokenId;
        _safeMint(to, tid);
        bondInfo[tid] = BondInfo({
            issuer: issuer,
            faceValue: faceValue,
            couponRateBPS: couponRateBPS,
            issueDate: issueDate,
            maturityDate: maturityDate,
            couponFreq: couponFreq,
            description: description
        });
        nextTokenId++;
        emit BondMinted(tid, to);
    }

    /// @notice Admin can update bond info if needed (e.g., add description)
    function updateBondInfo(
        uint256 tokenId,
        string calldata issuer,
        uint256 faceValue,
        uint256 couponRateBPS,
        uint256 issueDate,
        uint256 maturityDate,
        string calldata couponFreq,
        string calldata description
    ) external onlyAdmin {
        require(_exists(tokenId), "Nonexistent token");
        bondInfo[tokenId] = BondInfo({
            issuer: issuer,
            faceValue: faceValue,
            couponRateBPS: couponRateBPS,
            issueDate: issueDate,
            maturityDate: maturityDate,
            couponFreq: couponFreq,
            description: description
        });
        emit BondInfoUpdated(tokenId);
    }

    /// @notice Returns an on-chain JSON metadata URI with bond details
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ERC721: token does not exist");
        BondInfo memory b = bondInfo[tokenId];

        // Build attributes array for metadata
        string memory attributes = string.concat(
            '[', 
                _attr("Issuer", b.issuer), ',',
                _attr("Face Value", _formatNumber(b.faceValue)), ',',
                _attr("Coupon Rate (bps)", b.couponRateBPS.toString()), ',',
                _attr("Issue Date", _timestampToDateString(b.issueDate)), ',',
                _attr("Maturity Date", _timestampToDateString(b.maturityDate)), ',',
                _attr("Coupon Frequency", b.couponFreq),
            ']'
        );

        // Compose JSON
        string memory json = string.concat(
            '{',
                '"name":"WRP07 Bond #', tokenId.toString(), '",',
                '"description":"', _escape(b.description), '",',
                '"attributes":', attributes, ',',
                '"external_url":"",',
                '"properties":{',
                    '"faceValue":', b.faceValue.toString(), ',',
                    '"couponRateBPS":', b.couponRateBPS.toString(),
                '}',
            '}'
        );

        string memory encoded = Base64.encode(bytes(json));
        return string.concat("data:application/json;base64,", encoded);
    }

    // helpers for metadata formatting
    function _attr(string memory traitType, string memory value) internal pure returns (string memory) {
        return string.concat(
            '{',
                '"trait_type":"', _escape(traitType), '",',
                '"value":"', _escape(value), '"',
            '}'
        );
    }

    function _formatNumber(uint256 v) internal pure returns (string memory) {
        return v.toString();
    }

    // very minimal escaping for quotes/backslashes in strings
    function _escape(string memory s) internal pure returns (string memory) {
        bytes memory b = bytes(s);
        bytes memory out = new bytes(b.length * 2);
        uint256 j = 0;
        for (uint256 i = 0; i < b.length; i++) {
            bytes1 c = b[i];
            if (c == 0x22) { // "
                out[j++] = "\\";
                out[j++] = "\"";
            } else if (c == 0x5c) { // backslash
                out[j++] = "\\";
                out[j++] = "\\";
            } else {
                out[j++] = c;
            }
        }
        bytes memory trimmed = new bytes(j);
        for (uint256 k = 0; k < j; k++) trimmed[k] = out[k];
        return string(trimmed);
    }

    // naive timestamp to date string (YYYY-MM-DD) - for illustration; real implementation might push this off-chain
    function _timestampToDateString(uint256 ts) internal pure returns (string memory) {
        // This is a placeholder: converting UNIX timestamp to human-readable on-chain accurately is complex.
        // For production, store preformatted strings or do off-chain resolution.
        return ts.toString();
    }
}
