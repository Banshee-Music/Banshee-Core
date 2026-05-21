// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";

import {BansheeToken} from "../src/BansheeToken.sol";
import {BansheeTicketNFT} from "../src/BansheeTicketNFT.sol";
import {BansheeProofOfPerformance} from "../src/BansheeProofOfPerformance.sol";

contract DeployProofOfPerformance is Script {
    function run() external returns (
        BansheeToken token,
        BansheeTicketNFT ticket,
        BansheeProofOfPerformance marketplace
    ) {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address admin = vm.envAddress("ADMIN_ADDRESS");
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        uint96 platformFeeBps = uint96(vm.envOr("PLATFORM_FEE_BPS", uint256(500)));

        vm.startBroadcast(deployerKey);

        token = new BansheeToken(admin);
        ticket = new BansheeTicketNFT(admin);

        marketplace = new BansheeProofOfPerformance(
            admin,
            treasury,
            platformFeeBps,
            ticket,
            token
        );

        ticket.grantRole(ticket.TICKET_MINTER_ROLE(), address(marketplace));
        token.grantRole(token.REWARD_MINTER_ROLE(), address(marketplace));

        vm.stopBroadcast();
    }
}
