//SPDX-License-Identifier:MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "../../test/mocks/MockV3Aggregator.sol";
import {MockFailedMintDSC} from "../../test/mocks/MockFailedMintDSC.sol";
import {MockFailedTransfer} from "../../test/mocks/MockFailedTransfer.sol";
import {MockFailedTransferFrom} from "../../test/mocks/MockFailedTransferFrom.sol";

contract DSCEngoneTest is Test {
    DeployDSC public deployer;
    DecentralizedStableCoin public dsc;
    DSCEngine public dsce;
    MockFailedMintDSC publicMockFailedMintDSC;
    HelperConfig public config;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;
    address wbtc;

    uint256 public constant AMOUNT_TO_MINT = 100 ether; // 1 stable coin = $1 => 5000 stable coins = $5000
    uint256 public constant AMOUNT_TO_BURN = 100 ether;
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    address public USER = makeAddr("USER");

    uint256 public constant COLLATERAL_TO_COVER = 20 ether;
    address public LIQUIDATOR = makeAddr("Liquidator");

    address public newOwner = makeAddr("newOwner");

    uint256 public constant STARTING_ERC20_Balance = 10 ether;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc,) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_Balance);
        ERC20Mock(weth).mint(LIQUIDATOR, COLLATERAL_TO_COVER);
    }

    /////////////////////////////
    // constructor Tests  //////
    /////////////////////////////
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testUserERCafterdeposit() public liquidated {
        uint256 k = dsce.getTotalTokenToBeRedeemedByLiquidator(weth, AMOUNT_TO_MINT);
        //console.log(k);
        assertEq(0, ERC20Mock(weth).balanceOf(USER));
    }

    function testRevertsIfTokenLengthDoesMatchriceFeeds() public {
        //tokenAddresses.push(wbtc);
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);
        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    //////////////////////
    // Price Tests  //////
    //////////////////////

    function testGetUsdValue() public view {
        uint256 ethAmount = 15e18;
        uint256 expectedUsd = 30000e18;
        uint256 actualUsed = dsce.getUsdValue(weth, ethAmount);
        assertEq(expectedUsd, actualUsed);
    }

    function testGetTokenAmountFromUsd() public view {
        uint256 usdAmount = 100e18;
        //assume $2000 / 1Eth = $100 / ? ETH
        uint256 expectedWeth = 0.05e18;
        uint256 actualWeth = dsce.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(expectedWeth, actualWeth);
    }

    //////////////////////////////////
    // depositCollateral Tests  //////
    //////////////////////////////////

    function testRevertWithUnapprovedCollateral() public {
        ERC20Mock ranToken = new ERC20Mock();
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        dsce.depositCollateral(address(ranToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testRevertsIfTransferFromFails() public {
        // Arrange - Setup
        address owner = msg.sender;
        vm.prank(owner);
        MockFailedTransferFrom mockDsc = new MockFailedTransferFrom();
        tokenAddresses = [address(mockDsc)];
        priceFeedAddresses = [ethUsdPriceFeed];
        vm.prank(owner);
        DSCEngine mockDsce = new DSCEngine(tokenAddresses, priceFeedAddresses, address(mockDsc));
        mockDsc.mint(USER, AMOUNT_COLLATERAL);

        vm.prank(owner);
        mockDsc.transferOwnership(address(mockDsce));
        // Arrange - User
        vm.startPrank(USER);
        ERC20Mock(address(mockDsc)).approve(address(mockDsce), AMOUNT_COLLATERAL);
        // Act / Assert
        vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
        mockDsce.depositCollateral(address(mockDsc), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    modifier depositCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    modifier mintCollateral() {
        vm.prank(USER);
        dsce.mintDsc(AMOUNT_TO_MINT);
        _;
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(USER);
        uint256 expectedTotalDscMinted = 0;
        uint256 expectedDepositedAmount = dsce.getTokenAmountFromUsd(weth, collateralValueInUsd);
        assertEq(totalDscMinted, expectedTotalDscMinted);
        assertEq(AMOUNT_COLLATERAL, expectedDepositedAmount);
    }

    function testCanDepositWithoutMinting() public depositCollateral {
        uint256 balance = dsc.balanceOf(USER);
        assertEq(balance, 0);
    }

    function testDepositAndMint() public depositCollateral mintCollateral {
        uint256 actualCollateralDeposited = AMOUNT_COLLATERAL;
        uint256 actualDscMinted = AMOUNT_TO_MINT;
        uint256 expectedCollateralDeposited = dsce.getTotalTokensDeposited(USER);
        uint256 expectedDscMinted = dsce.getTotalDscMinted(USER);
        assertEq(actualCollateralDeposited, expectedCollateralDeposited);
        assertEq(actualDscMinted, expectedDscMinted);
        assertEq(AMOUNT_TO_MINT, dsc.balanceOf(USER));
    }

    ///////////////////////////////////////
    // depositCollateralAndMintDsc Tests //
    ///////////////////////////////////////

    function testRevertsIfMintAmountIsZero() public depositCollateral {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.mintDsc(0);
        vm.stopPrank();
    }

    modifier depositCollateralAndMintDsc() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        vm.stopPrank();
        _;
    }

    /*
    function testCollateralTransferFailure() public {
        vm.startPrank(USER);
        // Make the contract not have enough allowance
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        vm.expectRevert("Transfer failed");
        dsce.depositCollateral(wbtc, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }
     */

    function testRevertIfMintBreaksHealthFactor() public depositCollateral {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__BreaksHealthFactor.selector);
        dsce.mintDsc(10001 ether);
        vm.stopPrank();
    }

    /* function testRevertIfMintFails() public depositCollateral{
       ddress actualOwner = dsce.owner();
    vm.startPrank(actualOwner);
    dsce.transferOwnership(newOwner);
    vm.stopPrank();
    
    vm.startPrank(USER);
    vm.expectRevert(DSCEngine.DSCEngine_MintFailed.selector);
    dsce.mintDsc(AMOUNT_TO_MINT);
    vm.stopPrank(); a
    }
    */

    function testDepositCollateralAndMintDsc() public depositCollateralAndMintDsc {
        uint256 actualCollateralDeposited = AMOUNT_COLLATERAL;
        uint256 actualDscMinted = AMOUNT_TO_MINT;
        uint256 expectedCollateralDeposited = dsce.getTotalTokensDeposited(USER);
        uint256 expectedDscMinted = dsce.getTotalDscMinted(USER);
        assertEq(actualCollateralDeposited, expectedCollateralDeposited);
        assertEq(actualDscMinted, expectedDscMinted);
        assertEq(AMOUNT_TO_MINT, dsc.balanceOf(USER));
    }

    function testRevertsIfMintFails() public {
        // Arrange - Setup
        MockFailedMintDSC mockDsc = new MockFailedMintDSC();
        tokenAddresses = [weth];
        priceFeedAddresses = [ethUsdPriceFeed];
        address owner = msg.sender;
        vm.prank(owner);
        DSCEngine mockDsce = new DSCEngine(tokenAddresses, priceFeedAddresses, address(mockDsc));
        mockDsc.transferOwnership(address(mockDsce));
        // Arrange - User
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(mockDsce), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine_MintFailed.selector);
        mockDsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        vm.stopPrank();
    }

    ///////////////////////////////////////
    // redeemCollateral and Dsc Tests //
    ///////////////////////////////////////

    modifier redeemCollateral() {
        vm.startPrank(USER);
        dsce.redeemCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    modifier burnDsc() {
        vm.startPrank(USER);
        dsc.approve(address(dsce), AMOUNT_TO_BURN);
        dsce.burnDsc(AMOUNT_TO_BURN);
        vm.stopPrank();
        _;
    }

    modifier redeemCollateralAndBurnDsc() {
        vm.startPrank(USER);
        dsc.approve(address(dsce), AMOUNT_TO_BURN);
        dsce.redeemCollateralForDsc(weth, AMOUNT_COLLATERAL, AMOUNT_TO_BURN);
        vm.stopPrank();
        _;
    }

    function testRevertsIfTransferFails() public {
        // Arrange - Setup
        address owner = msg.sender;
        vm.prank(owner);
        MockFailedTransfer mockDsc = new MockFailedTransfer();
        tokenAddresses = [address(mockDsc)];
        priceFeedAddresses = [ethUsdPriceFeed];
        vm.prank(owner);
        DSCEngine mockDsce = new DSCEngine(tokenAddresses, priceFeedAddresses, address(mockDsc));
        mockDsc.mint(USER, AMOUNT_COLLATERAL);

        vm.prank(owner);
        mockDsc.transferOwnership(address(mockDsce));
        // Arrange - User
        vm.startPrank(USER);
        ERC20Mock(address(mockDsc)).approve(address(mockDsce), AMOUNT_COLLATERAL);
        // Act / Assert
        mockDsce.depositCollateral(address(mockDsc), AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
        mockDsce.redeemCollateral(address(mockDsc), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testRevertsIfCollateralAmountIsZero() public {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.redeemCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertIfRedeemCollateralBreaksHealthFactor() public depositCollateralAndMintDsc {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__BreaksHealthFactor.selector);
        dsce.redeemCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testBurnDscAndRedeemCollateral() public depositCollateralAndMintDsc redeemCollateralAndBurnDsc {
        uint256 actualDsc = dsce.getTotalDscMinted(USER);
        uint256 expectedDsc = 0;
        assertEq(actualDsc, expectedDsc);
    }

    function testDscCanBurn() public depositCollateralAndMintDsc burnDsc {
        uint256 userBalance = dsc.balanceOf(USER);
        assert(userBalance == AMOUNT_TO_MINT - AMOUNT_TO_BURN);
    }

    ///////////////////////////////////////
    // redeemCollateralAndDsc Tests //
    ///////////////////////////////////////
    function testREdeemCOllateralAndDsc() public depositCollateralAndMintDsc redeemCollateralAndBurnDsc {
        uint256 userBalance = dsc.balanceOf(USER);
        assert(userBalance == AMOUNT_TO_MINT - AMOUNT_TO_BURN);
    }

    function testCantLiquidateGoodHealthFactor() public depositCollateralAndMintDsc {
        ERC20Mock(weth).mint(LIQUIDATOR, STARTING_ERC20_Balance);
        vm.startPrank(LIQUIDATOR);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        dsc.approve(address(dsce), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOk.selector);
        dsce.liquidate(weth, USER, AMOUNT_TO_MINT);
        vm.stopPrank();
    }

    modifier liquidated() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        // console.log("UserBalance before depsoit:-", ERC20Mock(weth).balanceOf(USER));
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        // console.log("UserBalance after depsoit:-", ERC20Mock(weth).balanceOf(USER));
        vm.stopPrank();

        uint256 beforeHealthfactor = dsce.getHealthFactor(USER);
        //console.log("Health factor before:-",beforeHealthfactor);
        int256 ethUsdUpdatedPrice = 18e8;
        //console.log(ethUsdUpdatedPrice);
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);
        uint256 afterHealthfactor = dsce.getHealthFactor(USER);

        //uint256 userHealthFactor = dsce.getHealthFactor(USER);
        // user - 10 ether
        // liquidator = 20 ether
        // liquidataion ayyakka

        vm.startPrank(LIQUIDATOR);
        ERC20Mock(weth).approve(address(dsce), COLLATERAL_TO_COVER);
        // console.log("LiquidatorBalance after depsoit:-", ERC20Mock(weth).balanceOf(LIQUIDATOR));
        dsce.depositCollateralAndMintDsc(weth, COLLATERAL_TO_COVER, AMOUNT_TO_MINT);
        //console.log("LiquidatorBalance after depsoit:-", ERC20Mock(weth).balanceOf(LIQUIDATOR));
        dsc.approve(address(dsce), AMOUNT_TO_BURN);
        console.log("EngineBalance before liquidation:-", ERC20Mock(weth).balanceOf(address(dsce)));
        dsce.liquidate(weth, USER, AMOUNT_TO_MINT);
        // console.log("LiquidatorBalance after liquidation:-", ERC20Mock(weth).balanceOf(LIQUIDATOR));
        //console.log("UserBalance after liquidation:-", ERC20Mock(weth).balanceOf(USER));
        console.log("EngineBalance after liquidation:-", ERC20Mock(weth).balanceOf(address(dsce)));
        vm.stopPrank();
        _;
    }

    /*function testLiquidatorBalanceUpdatedCorrectlyOnLiquidation() public liquidated {
         uint256 liquidatorWethBalance = ERC20Mock(weth).balanceOf(LIQUIDATOR);
          uint256 expectedWeth = dsce.getTokenAmountFromUsd(weth, AMOUNT_TO_MINT) + (dsce.getTokenAmountFromUsd(weth, AMOUNT_TO_MINT) / dsce.getLiquidationBonus());

    }
    */

    function testLiquidatorMintedDscUpdatedCorrectly() public liquidated {
        uint256 expectedMintedDsc = 0;
        uint256 actualMintedDsc = dsce.getTotalDscMinted(LIQUIDATOR);
        assertEq(expectedMintedDsc, actualMintedDsc);
    }

    function testLiquidatorTokenBalanceUpdatedCorrectly() public {
        ERC20Mock(weth).mint(USER, STARTING_ERC20_Balance);
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        vm.stopPrank();
        int256 ethUsdUpdatedPrice = 18e8;
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);
        ERC20Mock(weth).mint(LIQUIDATOR, COLLATERAL_TO_COVER);
        vm.startPrank(LIQUIDATOR);
        ERC20Mock(weth).approve(address(dsce), COLLATERAL_TO_COVER);
        dsce.depositCollateralAndMintDsc(weth, COLLATERAL_TO_COVER, AMOUNT_TO_MINT);
        uint256 tokenBalanceAfterDeposit = ERC20Mock(weth).balanceOf(LIQUIDATOR);
        dsc.approve(address(dsce), AMOUNT_TO_BURN);
        dsce.liquidate(weth, USER, AMOUNT_TO_MINT);
        vm.stopPrank();
        uint256 expectedTokenBalance =
            tokenBalanceAfterDeposit + dsce.getTotalTokenToBeRedeemedByLiquidator(weth, AMOUNT_TO_MINT);

        assertEq(expectedTokenBalance, ERC20Mock(weth).balanceOf(LIQUIDATOR));
    }

    function testUserHealthIsAlright() public liquidated {
        uint256 health = dsce.getHealthFactor(USER);
        assertEq(health, type(uint256).max);
    }

    function testLiquidatorDscUpdatedCorrectly() public liquidated {
        uint256 expectedDsc = 0;
        uint256 actualDsc = dsce.getTotalDscMintedFromContract(LIQUIDATOR);
        assertEq(expectedDsc, actualDsc);
    }

    function testGetAccountCollateralValue() public depositCollateral {
        uint256 expectedCollateralValue = dsce.getUsdValue(weth, AMOUNT_COLLATERAL);
        uint256 actualCOllateralValue = dsce.getAccountCollateralValue(USER);
        assertEq(expectedCollateralValue, actualCOllateralValue);
    }

    function testRevertHealthFactorOk() public depositCollateralAndMintDsc {
        vm.startPrank(LIQUIDATOR);
        ERC20Mock(weth).approve(address(dsce), COLLATERAL_TO_COVER);
        dsce.depositCollateralAndMintDsc(weth, COLLATERAL_TO_COVER, AMOUNT_TO_MINT);
        dsc.approve(address(dsce), AMOUNT_TO_MINT);
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOk.selector);
        dsce.liquidate(weth, USER, AMOUNT_TO_MINT);
        vm.stopPrank();
    }

    function testGetTotalDscMinted() public depositCollateralAndMintDsc {
        uint256 expectedTotalDscMinted = dsce.getTotalDscMinted(USER);
        uint256 actualTotalDscMinted = AMOUNT_TO_MINT;
        assertEq(expectedTotalDscMinted, actualTotalDscMinted);
    }

    function testgetTotalTokenDeposited() public depositCollateral {
        uint256 expectedTotalTokenDeposited = AMOUNT_COLLATERAL;
        uint256 actualTotalTokenDeposited = dsce.getTotalTokensDeposited(USER);
        assertEq(expectedTotalTokenDeposited, actualTotalTokenDeposited);
    }

    function testLiquidatorstotalDSCMintedNotUpdatingCorrecly() public {
        //Liquidation
        //AMOUNT_COLLATERAL = 10 ether;
        //COLLATERAL_TO_COVER = 20ether;
        //AMOUNT_TO_MINT = 100 ether;
        //AMOUNT_TO_BURN = 100 ether
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        vm.stopPrank();
        int256 ethUsdUpdatedPrice = 18e8;
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);
        vm.startPrank(LIQUIDATOR);
        ERC20Mock(weth).approve(address(dsce), COLLATERAL_TO_COVER);
        dsce.depositCollateralAndMintDsc(weth, COLLATERAL_TO_COVER, AMOUNT_TO_MINT);
        dsc.approve(address(dsce), AMOUNT_TO_BURN);
        dsce.liquidate(weth, USER, AMOUNT_TO_MINT);
        vm.stopPrank();

        // 1. Liquuiator deposit 20 ether and mints 100 ether
        // 2. when Liquidator, liquidates USER, the Liquidators minter 100 ether has to be payed as debt to protocol
        // 3. And then S_totalDscMinted[LIQUIDATOR] should be equal to 0;
        // But here its not updating correctly

        assertEq(dsce.getTotalDscMinted(LIQUIDATOR), 0);
    }
}
