//SDX-License_Identifier: MIT

// have our invariant aka properties hold true for all the time

// Have Our invariants aka properties

// What are our invariants ?

// 1. The total supply of DSC should be less than the total value of Collateral

// 2. Getter view function should never revert <- everngreen invariant

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Handler} from "./Handler.t.sol";

contract Invariant is StdInvariant, Test {
    DeployDSC deployer;
    DSCEngine dsce;
    DecentralizedStableCoin dsc;
    HelperConfig config;
    address weth;
    address wbtc;
    Handler handler;

    function setUp() external {
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (,, weth, wbtc,) = config.activeNetworkConfig();
        handler = new Handler(dsce, dsc);
        targetContract(address(handler));
    }

    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
        // get the value of all the collateral in the protocol
        // compare it to the all the debt(dsc);
        uint256 totalSupply = dsc.totalSupply();
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(dsce));
        uint256 totalBtcDeposited = IERC20(wbtc).balanceOf(address(dsce));

        uint256 wethValue = dsce.getUsdValue(weth, totalWethDeposited);
        uint256 btcValue = dsce.getUsdValue(wbtc, totalBtcDeposited);

        console.log("Total Supply is:", totalSupply);
        console.log("Total Wethdeposited", totalWethDeposited);
        console.log("Total BtcDeposisted:", totalBtcDeposited);
        console.log("TImes Mint is called:", handler.timesMintIsCalled());
        assert(wethValue + btcValue >= totalSupply);
    }
}
