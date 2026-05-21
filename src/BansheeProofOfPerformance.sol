// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {BansheeTicketNFT} from "./BansheeTicketNFT.sol";
import {BansheeToken} from "./BansheeToken.sol";

/// @title BansheeProofOfPerformance
/// @notice Artist registry + AI-agent reviewed Greenfield marketplace + NFT tickets + performance rewards.
/// @dev Greenfield file permissions are handled off-chain by a relayer/agent. This contract anchors entitlement and reward events.
contract BansheeProofOfPerformance is AccessControl, ReentrancyGuard {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant AI_AGENT_ROLE = keccak256("AI_AGENT_ROLE");
    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE");

    uint96 public constant BPS_DENOMINATOR = 10_000;

    enum SubmissionStatus {
        None,
        Pending,
        Approved,
        Rejected,
        Listed
    }

    enum ListingType {
        Song,
        Album,
        Event
    }

    struct Artist {
        address wallet;
        string artistURI;
        bool active;
        bool verified;
        uint64 registeredAt;
        uint64 verifiedAt;
    }

    struct Submission {
        uint256 id;
        address artist;
        ListingType listingType;
        string title;
        string metadataURI;
        string greenfieldBucket;
        string greenfieldObject;
        string greenfieldGroup;
        string reviewURI;
        SubmissionStatus status;
        uint64 createdAt;
        uint64 reviewedAt;
    }

    struct Listing {
        uint256 id;
        uint256 submissionId;
        address artist;
        ListingType listingType;
        string title;
        string ticketURI;
        string metadataURI;
        string greenfieldBucket;
        string greenfieldObject;
        string greenfieldGroup;
        uint256 priceWei;
        uint256 maxTickets;
        uint256 ticketsMinted;
        uint256 totalPlays;
        uint256 totalRewardsMinted;
        bool active;
    }

    BansheeTicketNFT public immutable ticketNFT;
    BansheeToken public immutable bansheeToken;

    address public treasury;
    uint96 public platformFeeBps;

    uint256 public nextSubmissionId;
    uint256 public nextListingId;

    mapping(address => Artist) public artists;
    mapping(uint256 => Submission) public submissions;
    mapping(uint256 => Listing) public listings;

    /// @notice Optional anti-duplicate registry for SubQuery/agent reported performance proofs.
    mapping(bytes32 => bool) public usedPerformanceProofs;

    event TreasuryUpdated(address indexed treasury);
    event PlatformFeeUpdated(uint96 platformFeeBps);

    event ArtistRegistered(address indexed artist, string artistURI);
    event ArtistVerificationUpdated(address indexed artist, bool verified, string note);

    event SubmissionCreated(
        uint256 indexed submissionId,
        address indexed artist,
        ListingType indexed listingType,
        string title,
        string metadataURI,
        string greenfieldBucket,
        string greenfieldObject,
        string greenfieldGroup
    );

    event SubmissionReviewed(
        uint256 indexed submissionId,
        address indexed artist,
        SubmissionStatus status,
        string reviewURI
    );

    event ListingCreated(
        uint256 indexed listingId,
        uint256 indexed submissionId,
        address indexed artist,
        ListingType listingType,
        string title,
        uint256 priceWei,
        uint256 maxTickets,
        string greenfieldBucket,
        string greenfieldObject,
        string greenfieldGroup
    );

    event ListingStatusUpdated(uint256 indexed listingId, bool active);

    event TicketPurchased(
        uint256 indexed listingId,
        uint256 indexed ticketId,
        address indexed buyer,
        address artist,
        uint256 priceWei
    );

    event AgentTicketAirdropped(
        uint256 indexed listingId,
        uint256 indexed ticketId,
        address indexed recipient,
        address artist,
        string reason
    );

    event GreenfieldAccessRequested(
        uint256 indexed listingId,
        uint256 indexed ticketId,
        address indexed holder,
        string greenfieldBucket,
        string greenfieldObject,
        string greenfieldGroup
    );

    event PerformanceRecorded(
        uint256 indexed listingId,
        address indexed artist,
        address indexed listener,
        uint256 playCount,
        bytes32 proofHash,
        string source
    );

    event PerformanceRewardMinted(
        uint256 indexed listingId,
        address indexed artist,
        uint256 amount,
        uint256 indexed epoch,
        bytes32 proofHash
    );

    error InvalidAddress();
    error InvalidFee();
    error ArtistNotRegistered();
    error ArtistNotVerified();
    error InvalidSubmission();
    error InvalidListing();
    error InvalidState();
    error ListingInactive();
    error SoldOut();
    error WrongPayment();
    error TransferFailed();
    error DuplicateProof();

    constructor(
        address admin,
        address treasury_,
        uint96 platformFeeBps_,
        BansheeTicketNFT ticketNFT_,
        BansheeToken bansheeToken_
    ) {
        if (admin == address(0) || treasury_ == address(0)) revert InvalidAddress();
        if (address(ticketNFT_) == address(0) || address(bansheeToken_) == address(0)) revert InvalidAddress();
        if (platformFeeBps_ > BPS_DENOMINATOR) revert InvalidFee();

        treasury = treasury_;
        platformFeeBps = platformFeeBps_;
        ticketNFT = ticketNFT_;
        bansheeToken = bansheeToken_;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(AI_AGENT_ROLE, admin);
        _grantRole(TREASURY_ROLE, admin);
    }

    function registerArtist(string calldata artistURI) external {
        Artist storage artist = artists[msg.sender];

        artist.wallet = msg.sender;
        artist.artistURI = artistURI;
        artist.active = true;

        if (artist.registeredAt == 0) {
            artist.registeredAt = uint64(block.timestamp);
        }

        emit ArtistRegistered(msg.sender, artistURI);
    }

    function setArtistVerification(address artistWallet, bool verified, string calldata note)
        external
        onlyRole(AI_AGENT_ROLE)
    {
        Artist storage artist = artists[artistWallet];
        if (artist.wallet == address(0) || !artist.active) revert ArtistNotRegistered();

        artist.verified = verified;
        artist.verifiedAt = uint64(block.timestamp);

        emit ArtistVerificationUpdated(artistWallet, verified, note);
    }

    function submitContent(
        ListingType listingType,
        string calldata title,
        string calldata metadataURI,
        string calldata greenfieldBucket,
        string calldata greenfieldObject,
        string calldata greenfieldGroup
    ) external returns (uint256 submissionId) {
        Artist memory artist = artists[msg.sender];
        if (artist.wallet == address(0) || !artist.active) revert ArtistNotRegistered();
        if (!artist.verified) revert ArtistNotVerified();
        _requireGreenfield(greenfieldBucket, greenfieldObject, greenfieldGroup);

        submissionId = ++nextSubmissionId;

        submissions[submissionId] = Submission({
            id: submissionId,
            artist: msg.sender,
            listingType: listingType,
            title: title,
            metadataURI: metadataURI,
            greenfieldBucket: greenfieldBucket,
            greenfieldObject: greenfieldObject,
            greenfieldGroup: greenfieldGroup,
            reviewURI: "",
            status: SubmissionStatus.Pending,
            createdAt: uint64(block.timestamp),
            reviewedAt: 0
        });

        emit SubmissionCreated(
            submissionId,
            msg.sender,
            listingType,
            title,
            metadataURI,
            greenfieldBucket,
            greenfieldObject,
            greenfieldGroup
        );
    }

    function reviewSubmission(
        uint256 submissionId,
        bool approved,
        string calldata reviewURI
    ) external onlyRole(AI_AGENT_ROLE) {
        Submission storage submission = submissions[submissionId];
        if (submission.id == 0) revert InvalidSubmission();
        if (submission.status != SubmissionStatus.Pending) revert InvalidState();

        submission.status = approved ? SubmissionStatus.Approved : SubmissionStatus.Rejected;
        submission.reviewURI = reviewURI;
        submission.reviewedAt = uint64(block.timestamp);

        emit SubmissionReviewed(submissionId, submission.artist, submission.status, reviewURI);
    }

    function agentCreateListingFromSubmission(
        uint256 submissionId,
        uint256 priceWei,
        uint256 maxTickets,
        string calldata ticketURI
    ) external onlyRole(AI_AGENT_ROLE) returns (uint256 listingId) {
        Submission storage submission = submissions[submissionId];
        if (submission.id == 0) revert InvalidSubmission();
        if (submission.status != SubmissionStatus.Approved) revert InvalidState();
        if (maxTickets == 0) revert InvalidListing();

        submission.status = SubmissionStatus.Listed;
        listingId = ++nextListingId;

        listings[listingId] = Listing({
            id: listingId,
            submissionId: submissionId,
            artist: submission.artist,
            listingType: submission.listingType,
            title: submission.title,
            ticketURI: ticketURI,
            metadataURI: submission.metadataURI,
            greenfieldBucket: submission.greenfieldBucket,
            greenfieldObject: submission.greenfieldObject,
            greenfieldGroup: submission.greenfieldGroup,
            priceWei: priceWei,
            maxTickets: maxTickets,
            ticketsMinted: 0,
            totalPlays: 0,
            totalRewardsMinted: 0,
            active: true
        });

        emit ListingCreated(
            listingId,
            submissionId,
            submission.artist,
            submission.listingType,
            submission.title,
            priceWei,
            maxTickets,
            submission.greenfieldBucket,
            submission.greenfieldObject,
            submission.greenfieldGroup
        );
    }

    function purchaseTicket(uint256 listingId) external payable nonReentrant returns (uint256 ticketId) {
        Listing storage listing = listings[listingId];
        if (listing.id == 0) revert InvalidListing();
        if (!listing.active) revert ListingInactive();
        if (listing.ticketsMinted >= listing.maxTickets) revert SoldOut();
        if (msg.value != listing.priceWei) revert WrongPayment();

        listing.ticketsMinted += 1;

        uint256 platformAmount = (msg.value * platformFeeBps) / BPS_DENOMINATOR;
        uint256 artistAmount = msg.value - platformAmount;

        if (platformAmount > 0) _safeTransferNative(treasury, platformAmount);
        if (artistAmount > 0) _safeTransferNative(listing.artist, artistAmount);

        ticketId = ticketNFT.mintTicket(msg.sender, listingId, listing.ticketURI);

        emit TicketPurchased(listingId, ticketId, msg.sender, listing.artist, msg.value);
    }

    function agentAirdropTicket(uint256 listingId, address recipient, string calldata reason)
        external
        onlyRole(AI_AGENT_ROLE)
        nonReentrant
        returns (uint256 ticketId)
    {
        if (recipient == address(0)) revert InvalidAddress();

        Listing storage listing = listings[listingId];
        if (listing.id == 0) revert InvalidListing();
        if (!listing.active) revert ListingInactive();
        if (listing.ticketsMinted >= listing.maxTickets) revert SoldOut();

        listing.ticketsMinted += 1;
        ticketId = ticketNFT.mintTicket(recipient, listingId, listing.ticketURI);

        emit AgentTicketAirdropped(listingId, ticketId, recipient, listing.artist, reason);
    }

    function requestGreenfieldAccess(uint256 listingId, uint256 ticketId) external {
        Listing memory listing = listings[listingId];
        if (listing.id == 0) revert InvalidListing();
        if (ticketNFT.ownerOf(ticketId) != msg.sender) revert InvalidState();
        if (ticketNFT.ticketListingId(ticketId) != listingId) revert InvalidState();

        emit GreenfieldAccessRequested(
            listingId,
            ticketId,
            msg.sender,
            listing.greenfieldBucket,
            listing.greenfieldObject,
            listing.greenfieldGroup
        );
    }

    function recordPerformance(
        uint256 listingId,
        address listener,
        uint256 playCount,
        bytes32 proofHash,
        string calldata source
    ) external onlyRole(AI_AGENT_ROLE) {
        Listing storage listing = listings[listingId];
        if (listing.id == 0) revert InvalidListing();
        if (listener == address(0)) revert InvalidAddress();
        if (playCount == 0) revert InvalidListing();
        if (proofHash != bytes32(0)) {
            if (usedPerformanceProofs[proofHash]) revert DuplicateProof();
            usedPerformanceProofs[proofHash] = true;
        }

        listing.totalPlays += playCount;

        emit PerformanceRecorded(
            listingId,
            listing.artist,
            listener,
            playCount,
            proofHash,
            source
        );
    }

    function mintArtistPerformanceReward(
        uint256 listingId,
        uint256 amount,
        uint256 epoch,
        bytes32 proofHash
    ) external onlyRole(AI_AGENT_ROLE) {
        Listing storage listing = listings[listingId];
        if (listing.id == 0) revert InvalidListing();
        if (amount == 0) revert InvalidListing();

        listing.totalRewardsMinted += amount;
        bansheeToken.mintPerformanceReward(listing.artist, amount);

        emit PerformanceRewardMinted(listingId, listing.artist, amount, epoch, proofHash);
    }

    function setListingActive(uint256 listingId, bool active) external onlyRole(AI_AGENT_ROLE) {
        Listing storage listing = listings[listingId];
        if (listing.id == 0) revert InvalidListing();

        listing.active = active;
        emit ListingStatusUpdated(listingId, active);
    }

    function setTreasury(address treasury_) external onlyRole(TREASURY_ROLE) {
        if (treasury_ == address(0)) revert InvalidAddress();
        treasury = treasury_;
        emit TreasuryUpdated(treasury_);
    }

    function setPlatformFeeBps(uint96 platformFeeBps_) external onlyRole(TREASURY_ROLE) {
        if (platformFeeBps_ > BPS_DENOMINATOR) revert InvalidFee();
        platformFeeBps = platformFeeBps_;
        emit PlatformFeeUpdated(platformFeeBps_);
    }

    function _requireGreenfield(
        string calldata greenfieldBucket,
        string calldata greenfieldObject,
        string calldata greenfieldGroup
    ) internal pure {
        if (
            bytes(greenfieldBucket).length == 0 ||
            bytes(greenfieldObject).length == 0 ||
            bytes(greenfieldGroup).length == 0
        ) {
            revert InvalidSubmission();
        }
    }

    function _safeTransferNative(address to, uint256 amount) internal {
        (bool ok,) = payable(to).call{value: amount}("");
        if (!ok) revert TransferFailed();
    }
}
