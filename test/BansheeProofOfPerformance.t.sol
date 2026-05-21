// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";

import {BansheeToken} from "../src/BansheeToken.sol";
import {BansheeTicketNFT} from "../src/BansheeTicketNFT.sol";
import {BansheeProofOfPerformance} from "../src/BansheeProofOfPerformance.sol";

contract BansheeProofOfPerformanceTest is Test {
    BansheeToken token;
    BansheeTicketNFT ticket;
    BansheeProofOfPerformance market;

    address admin = address(0xA11CE);
    address treasury = address(0xBEEF);
    address agent = address(0xA6E17);
    address artist = address(0xA27157);
    address fan = address(0xF00D);

    function setUp() public {
        vm.deal(fan, 10 ether);

        vm.startPrank(admin);
        token = new BansheeToken(admin);
        ticket = new BansheeTicketNFT(admin);
        market = new BansheeProofOfPerformance(
            admin,
            treasury,
            500,
            ticket,
            token
        );

        ticket.grantRole(ticket.TICKET_MINTER_ROLE(), address(market));
        token.grantRole(token.REWARD_MINTER_ROLE(), address(market));
        market.grantRole(market.AI_AGENT_ROLE(), agent);
        vm.stopPrank();
    }

    function _registerVerifySubmitApproveAndList()
        internal
        returns (uint256 submissionId, uint256 listingId)
    {
        vm.prank(artist);
        market.registerArtist("greenfield://artist-profile/lamont");

        vm.prank(agent);
        market.setArtistVerification(artist, true, "verified by bnb ai agent");

        vm.prank(artist);
        submissionId = market.submitContent(
            BansheeProofOfPerformance.ListingType.Song,
            "Space Study Lo-Fi",
            "greenfield://banshee-meta/song-1.json",
            "banshee-bucket",
            "songs/song-1.flac",
            "banshee-access-group"
        );

        vm.prank(agent);
        market.reviewSubmission(submissionId, true, "greenfield://reviews/song-1-review.json");

        vm.prank(agent);
        listingId = market.agentCreateListingFromSubmission(
            submissionId,
            0.01 ether,
            100,
            "greenfield://banshee-meta/ticket-1.json"
        );
    }

    function testArtistMustBeVerifiedBeforeSubmitting() public {
        vm.prank(artist);
        market.registerArtist("greenfield://artist-profile/not-yet-verified");

        vm.prank(artist);
        vm.expectRevert(BansheeProofOfPerformance.ArtistNotVerified.selector);
        market.submitContent(
            BansheeProofOfPerformance.ListingType.Song,
            "Unverified Song",
            "greenfield://metadata/unverified.json",
            "bucket",
            "object",
            "group"
        );
    }

    function testAgentCanApproveAndCreateListing() public {
        (uint256 submissionId, uint256 listingId) = _registerVerifySubmitApproveAndList();

        assertEq(submissionId, 1);
        assertEq(listingId, 1);

        (
            uint256 id,
            uint256 storedSubmissionId,
            address storedArtist,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            uint256 priceWei,
            uint256 maxTickets,
            uint256 ticketsMinted,
            ,
            ,
            bool active
        ) = market.listings(listingId);

        assertEq(id, listingId);
        assertEq(storedSubmissionId, submissionId);
        assertEq(storedArtist, artist);
        assertEq(priceWei, 0.01 ether);
        assertEq(maxTickets, 100);
        assertEq(ticketsMinted, 0);
        assertTrue(active);
    }

    function testFanCanPurchaseTicket() public {
        (, uint256 listingId) = _registerVerifySubmitApproveAndList();

        uint256 artistBefore = artist.balance;
        uint256 treasuryBefore = treasury.balance;

        vm.prank(fan);
        uint256 ticketId = market.purchaseTicket{value: 0.01 ether}(listingId);

        assertEq(ticket.ownerOf(ticketId), fan);
        assertEq(ticket.ticketListingId(ticketId), listingId);

        assertEq(treasury.balance - treasuryBefore, 0.0005 ether);
        assertEq(artist.balance - artistBefore, 0.0095 ether);
    }

    function testAgentCanAirdropTicket() public {
        (, uint256 listingId) = _registerVerifySubmitApproveAndList();

        vm.prank(agent);
        uint256 ticketId = market.agentAirdropTicket(listingId, fan, "agent-curated-airdrop");

        assertEq(ticket.ownerOf(ticketId), fan);
        assertEq(ticket.ticketListingId(ticketId), listingId);
    }

    function testHolderCanRequestGreenfieldAccess() public {
        (, uint256 listingId) = _registerVerifySubmitApproveAndList();

        vm.prank(agent);
        uint256 ticketId = market.agentAirdropTicket(listingId, fan, "access test");

        vm.prank(fan);
        market.requestGreenfieldAccess(listingId, ticketId);
    }

    function testAgentRecordsPerformanceAndMintsReward() public {
        (, uint256 listingId) = _registerVerifySubmitApproveAndList();

        bytes32 proofHash = keccak256("subquery-epoch-1-listing-1-fan-play");

        vm.prank(agent);
        market.recordPerformance(listingId, fan, 3, proofHash, "subquery:epoch:1");

        vm.prank(agent);
        market.mintArtistPerformanceReward(listingId, 100 ether, 1, proofHash);

        assertEq(token.balanceOf(artist), 100 ether);
    }

    function testDuplicatePerformanceProofReverts() public {
        (, uint256 listingId) = _registerVerifySubmitApproveAndList();

        bytes32 proofHash = keccak256("duplicate-proof");

        vm.prank(agent);
        market.recordPerformance(listingId, fan, 1, proofHash, "subquery:epoch:1");

        vm.prank(agent);
        vm.expectRevert(BansheeProofOfPerformance.DuplicateProof.selector);
        market.recordPerformance(listingId, fan, 1, proofHash, "subquery:epoch:1");
    }
}
