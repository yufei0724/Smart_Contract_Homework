// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
Idea:
- Mint an ERC-721 twin for a component batch.
- Store only small pointers on-chain (hashes + CIDs).
- Approved test houses publish a report CID and set an access fee.
- Buyers pay per access. Payment goes directly to the test house.
*/

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract SpaceDocTwin is ERC721, AccessControl, ReentrancyGuard {
    // Roles (consortium governance)
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");             // distributor / prime
    bytes32 public constant TEST_HOUSE_ROLE = keccak256("TEST_HOUSE_ROLE");     // approved radiation lab
    bytes32 public constant ARBITER_ROLE = keccak256("ARBITER_ROLE");           // dispute/slashing authority

    // Global variables
    uint256 public tokenCounter;
    uint256 public minStakeWei = 0.2 ether;         // adjust for pilot
    uint256 public constant DISPUTE_WINDOW = 14 days;

    // Data storage
    struct TwinData {
        bytes32 lotHash;            // hash of lot code (avoid leaking)
        bytes32 partNumberHash;     // hash of internal part number
        string metaCID;             // IPFS CID for JSON metadata
        string reportCID;           // IPFS/Arweave CID for radiation report
        address testHouse;          // who published the report
        uint256 accessFeeWei;       // fee per access
        uint256 stakeWei;           // stake locked when report is published
        uint256 reportTimestamp;    // when report is published
        bool reportPublished;
    }

    mapping(uint256 => TwinData) public registry;

    // Access rights for gated reportCID
    mapping(uint256 => mapping(address => bool)) public hasAccess;

    // Events (for audit trail + indexers)
    event TwinMinted(uint256 indexed tokenId, address indexed owner, bytes32 lotHash);
    event MetadataUpdated(uint256 indexed tokenId, string metaCID);
    event ReportPublished(uint256 indexed tokenId, address indexed testHouse, string reportCID, uint256 feeWei);
    event AccessPurchased(uint256 indexed tokenId, address indexed buyer, uint256 feeWei);
    event DisputeOpened(uint256 indexed tokenId, address indexed opener, string evidenceCID);
    event StakeSlashed(uint256 indexed tokenId, address indexed testHouse, uint256 amountWei);
    event StakeWithdrawn(uint256 indexed tokenId, address indexed testHouse, uint256 amountWei);

    function _tokenExists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    constructor(address admin) ERC721("Space Documentation Twin", "SDT") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(ARBITER_ROLE, admin);
        tokenCounter = 0;
    }

    // Special Function 1: mint a twin
    function mintTwin(
        address to,
        bytes32 lotHash,
        bytes32 partNumberHash,
        string calldata metaCID
    ) external onlyRole(MINTER_ROLE) returns (uint256) {
        uint256 tokenId = tokenCounter;
        tokenCounter += 1;

        _safeMint(to, tokenId);

        registry[tokenId] = TwinData({
            lotHash: lotHash,
            partNumberHash: partNumberHash,
            metaCID: metaCID,
            reportCID: "",
            testHouse: address(0),
            accessFeeWei: 0,
            stakeWei: 0,
            reportTimestamp: 0,
            reportPublished: false
        });

        emit TwinMinted(tokenId, to, lotHash);
        return tokenId;
    }

    // Optional: update metadata CID
    function updateMetaCID(uint256 tokenId, string calldata newMetaCID) external {
        require(_tokenExists(tokenId), "Token does not exist");
        require(ownerOf(tokenId) == msg.sender || hasRole(MINTER_ROLE, msg.sender), "Not allowed");

        registry[tokenId].metaCID = newMetaCID;
        emit MetadataUpdated(tokenId, newMetaCID);
    }

    // Special Function 2: publish a report CID and set a fee
    // Requires a stake to reduce spam and to support slashing if needed.
    function publishReport(
        uint256 tokenId,
        string calldata reportCID,
        uint256 feeWei
    ) external payable onlyRole(TEST_HOUSE_ROLE) {
        require(_tokenExists(tokenId), "Token does not exist");
        require(msg.value >= minStakeWei, "Stake too small");

        TwinData storage t = registry[tokenId];
        require(!t.reportPublished, "Report already published");

        t.reportCID = reportCID;
        t.testHouse = msg.sender;
        t.accessFeeWei = feeWei;
        t.stakeWei = msg.value;
        t.reportTimestamp = block.timestamp;
        t.reportPublished = true;

        emit ReportPublished(tokenId, msg.sender, reportCID, feeWei);
    }

    // Special Function 3: pay-per-access
    // Payment goes directly to the test house. Access right is recorded on-chain.
    function buyAccess(uint256 tokenId) external payable nonReentrant {
        require(_tokenExists(tokenId), "Token does not exist");

        TwinData storage t = registry[tokenId];
        require(t.reportPublished, "No report");
        require(msg.value == t.accessFeeWei, "Wrong fee");

        hasAccess[tokenId][msg.sender] = true;

        (bool ok, ) = t.testHouse.call{value: msg.value}("");
        require(ok, "Payment failed");

        emit AccessPurchased(tokenId, msg.sender, msg.value);
    }

    // Special Function 4: gated read of reportCID
    function getReportCID(uint256 tokenId) external view returns (string memory) {
        require(_tokenExists(tokenId), "Token does not exist");

        if (ownerOf(tokenId) == msg.sender) return registry[tokenId].reportCID;
        if (hasAccess[tokenId][msg.sender]) return registry[tokenId].reportCID;
        if (hasRole(ARBITER_ROLE, msg.sender)) return registry[tokenId].reportCID;

        revert("No access");
    }

    // Dispute + slashing (basic governance tools)
    function openDispute(uint256 tokenId, string calldata evidenceCID) external {
        require(_tokenExists(tokenId), "Token does not exist");
        require(registry[tokenId].reportPublished, "No report");
        emit DisputeOpened(tokenId, msg.sender, evidenceCID);
    }

    function slashStake(uint256 tokenId, uint256 amountWei) external onlyRole(ARBITER_ROLE) nonReentrant {
        TwinData storage t = registry[tokenId];
        require(t.stakeWei >= amountWei, "Too much");

        t.stakeWei -= amountWei;
        emit StakeSlashed(tokenId, t.testHouse, amountWei);

        // In a full design, slashed stake could be sent to a treasury or burned.
    }

    function withdrawStake(uint256 tokenId) external nonReentrant {
        TwinData storage t = registry[tokenId];
        require(t.testHouse == msg.sender, "Not test house");
        require(t.reportPublished, "No report");
        require(block.timestamp >= t.reportTimestamp + DISPUTE_WINDOW, "Too early");

        uint256 amt = t.stakeWei;
        t.stakeWei = 0;

        (bool ok, ) = msg.sender.call{value: amt}("");
        require(ok, "Withdraw failed");

        emit StakeWithdrawn(tokenId, msg.sender, amt);
    }

    // Admin parameter
    function setMinStakeWei(uint256 newMin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        minStakeWei = newMin;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, AccessControl)
        returns (bool)
        {
        return super.supportsInterface(interfaceId);
    }}

 