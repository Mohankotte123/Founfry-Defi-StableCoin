//SPDX-License-Identifier:MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DeployStableCoin} from "../script/DeployStableCoin.s.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";

contract mintTest is Test {
    DeployStableCoin public deployer;
    DecentralizedStableCoin public stableCoin;
    address ENGINE = makeAddr("ENGINE");
    address USER = makeAddr("USER");

    function setUp() public {
        deployer = new DeployStableCoin();
        stableCoin = deployer.run();
        vm.deal(ENGINE, 1 ether);
    }

    function testEngineHasMintingCorrectly() public {
        //Arrange
        vm.prank(msg.sender);
        //Act
        stableCoin.mint(address(this), 100);
        //assert
        assert(stableCoin.balanceOf(address(this)) == 100);
    }

    function testEngineHasBurningCorrectly() public {
        //Arrange
        vm.prank(msg.sender);
        stableCoin.mint(msg.sender, 100);
        uint256 totalBalance = stableCoin.balanceOf(msg.sender);
        //Act
        uint256 burn = 20;
        vm.prank(msg.sender);
        stableCoin.burn(burn);
        //assert
        assert(stableCoin.balanceOf(msg.sender) == totalBalance - burn);
    }
}
