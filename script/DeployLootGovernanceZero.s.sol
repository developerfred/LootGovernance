// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {LootGovernor, LootTimelock} from "../src/LootGovernor.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployLootGovernanceZero is Script {
    uint256 public constant MIN_DELAY = 3600; // 1 hour
    uint256 public constant VOTING_DELAY = 7200; // 1 day
    uint256 public constant VOTING_PERIOD = 50400; // 1 week
    address public constant LOOT = 0xFF9C1b15B16263C61d017ee9F65C50e4AE0113D7;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);

        // Deploy Timelock Implementation
        LootTimelock timelockImplementation = new LootTimelock();
        
        // Prepare timelock initialization data
        bytes memory timelockInitData = abi.encodeWithSelector(
            LootTimelock.initialize.selector,
            MIN_DELAY,
            new address[](0),
            new address[](0),
            deployer
        );
        
        // Deploy Timelock Proxy
        ERC1967Proxy timelockProxy = new ERC1967Proxy(
            address(timelockImplementation),
            timelockInitData
        );
        
        LootTimelock timelock = LootTimelock(payable(address(timelockProxy)));

        // Deploy Governor Implementation
        LootGovernor implementation = new LootGovernor();

        // Prepare governor initialization data
        bytes memory governorInitData = abi.encodeWithSelector(
            LootGovernor.initialize.selector,
            LOOT,
            address(timelock),
            VOTING_DELAY,
            VOTING_PERIOD,
            deployer 
        );

        // Deploy Governor Proxy
        ERC1967Proxy governorProxy = new ERC1967Proxy(
            address(implementation),
            governorInitData
        );

        LootGovernor governor = LootGovernor(payable(address(governorProxy)));

        // Setup roles
        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();  

        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(executorRole, address(0));
        timelock.revokeRole(adminRole, deployer);

        // Transferir ownership para endereço zero após setup completo
        governor.renounceOwnership();

        console2.log("Timelock Implementation deployed to:", address(timelockImplementation));
        console2.log("Timelock Proxy deployed to:", address(timelockProxy));
        console2.log("Governor Implementation deployed to:", address(implementation));
        console2.log("Governor Proxy deployed to:", address(governorProxy));
        console2.log("Ownership transferred to zero address");

        vm.stopBroadcast();
    }
}