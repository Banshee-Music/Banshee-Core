// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract BansheeTicketNFT is ERC721, AccessControl {
    /**
     * Marketplace / agent role allowed to mint tickets
     */
    bytes32 public constant TICKET_MINTER_ROLE =
        keccak256("TICKET_MINTER_ROLE");

    uint256 public nextTokenId;

    struct TicketData {
        uint256 listingId;
        string metadataURI;
    }

    mapping(uint256 => TicketData) public ticketData;

    event TicketMinted(
        uint256 indexed tokenId,
        address indexed to,
        uint256 indexed listingId,
        string metadataURI
    );

    constructor(address admin)
        ERC721("Banshee Access Ticket", "BANTIX")
    {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);

        _grantRole(TICKET_MINTER_ROLE, admin);
    }

    /**
     * Mint access ticket NFT
     */
    function mintTicket(
        address to,
        uint256 listingId,
        string calldata metadataURI
    )
        external
        onlyRole(TICKET_MINTER_ROLE)
        returns (uint256 tokenId)
    {
        tokenId = ++nextTokenId;

        _safeMint(to, tokenId);

        ticketData[tokenId] = TicketData({
            listingId: listingId,
            metadataURI: metadataURI
        });

        emit TicketMinted(
            tokenId,
            to,
            listingId,
            metadataURI
        );
    }

    /**
     * NFT metadata
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(
            _ownerOf(tokenId) != address(0),
            "Token does not exist"
        );

        return ticketData[tokenId].metadataURI;
    }

    /**
     * Compatibility getter expected by
     * BansheeProofOfPerformance.sol
     */
    function ticketListingId(uint256 tokenId)
        external
        view
        returns (uint256)
    {
        require(
            _ownerOf(tokenId) != address(0),
            "Token does not exist"
        );

        return ticketData[tokenId].listingId;
    }

    /**
     * OpenZeppelin interface support
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}