//SPDX-Licenser-identifier:MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Test, console} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";

contract DeployStableCoin is Script {
    function run() external returns (DecentralizedStableCoin) {
        vm.startBroadcast();
        DecentralizedStableCoin stableCoin = new DecentralizedStableCoin();
        console.log(address(this));
        console.log(msg.sender);
        vm.stopBroadcast();
        return stableCoin;
    }
}
