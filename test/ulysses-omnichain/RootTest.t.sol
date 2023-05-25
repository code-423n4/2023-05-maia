//SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.16;
//TEST

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {stdError} from "forge-std/StdError.sol";
import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

//COMPONENTS
import {RootPort} from "@omni/RootPort.sol";
import {ArbitrumBranchPort} from "@omni/ArbitrumBranchPort.sol";
import {BranchPort} from "@omni/BranchPort.sol";

import {RootBridgeAgent, WETH9} from "./mocks/MockRootBridgeAgent.t.sol";
import {BranchBridgeAgent} from "./mocks/MockBranchBridgeAgent.t.sol";
import {ArbitrumBranchBridgeAgent} from "@omni/ArbitrumBranchBridgeAgent.sol";

import {BaseBranchRouter} from "@omni/BaseBranchRouter.sol";
import {MulticallRootRouter} from "@omni/MulticallRootRouter.sol";
import {CoreRootRouter} from "@omni/CoreRootRouter.sol";
import {CoreBranchRouter} from "@omni/CoreBranchRouter.sol";
import {ArbitrumCoreBranchRouter} from "@omni/ArbitrumCoreBranchRouter.sol";

import {ERC20hTokenBranch} from "@omni/token/ERC20hTokenBranch.sol";
import {ERC20hTokenRoot} from "@omni/token/ERC20hTokenRoot.sol";
import {ERC20hTokenRootFactory} from "@omni/factories/ERC20hTokenRootFactory.sol";
import {ERC20hTokenBranchFactory} from "@omni/factories/ERC20hTokenBranchFactory.sol";
import {RootBridgeAgentFactory} from "@omni/factories/RootBridgeAgentFactory.sol";
import {BranchBridgeAgentFactory} from "@omni/factories/BranchBridgeAgentFactory.sol";
import {ArbitrumBranchBridgeAgentFactory} from "@omni/factories/ArbitrumBranchBridgeAgentFactory.sol";

//UTILS
import {DepositParams, DepositMultipleParams} from "./mocks/MockRootBridgeAgent.t.sol";
import {Deposit, DepositStatus, DepositMultipleInput, DepositInput} from "@omni/interfaces/IBranchBridgeAgent.sol";
import {Settlement, SettlementStatus} from "@omni/interfaces/IRootBridgeAgent.sol";

import {WETH9 as WETH} from "./mocks/WETH9.sol";
import {Multicall2} from "./mocks/Multicall2.sol";

pragma solidity ^0.8.0;

interface IAnycallApp {
    /// (required) call on the destination chain to exec the interaction
    function anyExecute(bytes calldata _data) external returns (bool success, bytes memory result);

    /// (optional,advised) call back on the originating chain if the cross chain interaction fails
    /// `_data` is the orignal interaction arguments exec on the destination chain
    function anyFallback(bytes calldata _data) external returns (bool success, bytes memory result);
}

contract RootTest is DSTestPlus {
    // Consts

    uint24 constant rootChainId = uint24(42161);

    uint24 constant avaxChainId = uint24(43114);

    uint24 constant ftmChainId = uint24(2040);

    //// System contracts

    // Root

    RootPort rootPort;

    ERC20hTokenRootFactory hTokenFactory;

    RootBridgeAgentFactory bridgeAgentFactory;

    RootBridgeAgent coreBridgeAgent;

    RootBridgeAgent multicallBridgeAgent;

    CoreRootRouter rootCoreRouter;

    MulticallRootRouter rootMulticallRouter;

    // Arbitrum Branch

    ArbitrumBranchPort arbitrumPort;

    ERC20hTokenBranchFactory localHTokenFactory;

    ArbitrumBranchBridgeAgentFactory arbitrumBranchBridgeAgentFactory;

    ArbitrumBranchBridgeAgent arbitrumCoreBridgeAgent;

    ArbitrumBranchBridgeAgent arbitrumMulticallBridgeAgent;

    ArbitrumCoreBranchRouter arbitrumCoreRouter;

    BaseBranchRouter arbitrumMulticallRouter;

    // Avax Branch

    BranchPort avaxPort;

    ERC20hTokenBranchFactory avaxHTokenFactory;

    BranchBridgeAgentFactory avaxBranchBridgeAgentFactory;

    BranchBridgeAgent avaxCoreBridgeAgent;

    BranchBridgeAgent avaxMulticallBridgeAgent;

    CoreBranchRouter avaxCoreRouter;

    BaseBranchRouter avaxMulticallRouter;

    // Ftm Branch

    BranchPort ftmPort;

    ERC20hTokenBranchFactory ftmHTokenFactory;

    BranchBridgeAgentFactory ftmBranchBridgeAgentFactory;

    BranchBridgeAgent ftmCoreBridgeAgent;

    BranchBridgeAgent ftmMulticallBridgeAgent;

    CoreBranchRouter ftmCoreRouter;

    BaseBranchRouter ftmMulticallRouter;

    // ERC20s from different chains.

    address avaxMockAssethToken;

    MockERC20 avaxMockAssetToken;

    address ftmMockAssethToken;

    MockERC20 ftmMockAssetToken;

    ERC20hTokenRoot arbitrumMockAssethToken;

    MockERC20 arbitrumMockToken;

    // Mocks

    address arbitrumGlobalToken;
    address avaxGlobalToken;
    address ftmGlobalToken;

    address arbitrumWrappedNativeToken;
    address avaxWrappedNativeToken;
    address ftmWrappedNativeToken;

    address arbitrumLocalWrappedNativeToken;
    address avaxLocalWrappedNativeToken;
    address ftmLocalWrappedNativeToken;

    address multicallAddress;

    address testGasPoolAddress = address(0xFFFF);

    address nonFungiblePositionManagerAddress = address(0xABAD);

    address avaxLocalarbitrumWrappedNativeTokenAddress = address(0xBFFF);
    address avaxUnderlyingarbitrumWrappedNativeTokenAddress = address(0xFFFB);

    address ftmLocalarbitrumWrappedNativeTokenAddress = address(0xABBB);
    address ftmUnderlyingarbitrumWrappedNativeTokenAddress = address(0xAAAB);

    address avaxCoreBridgeAgentAddress = address(0xBEEF);

    address avaxMulticallBridgeAgentAddress = address(0xEBFE);

    address avaxPortAddress = address(0xFEEB);

    address ftmCoreBridgeAgentAddress = address(0xCACA);

    address ftmMulticallBridgeAgentAddress = address(0xACAC);

    address ftmPortAddressM = address(0xABAC);

    address localAnyConfig = address(new MockAnyConfig());

    address localAnyCallAddress = address(new MockAnycall(localAnyConfig));

    address localAnyCallExecutorAddress = address(0xABFD);

    address owner = address(this);

    address dao = address(this);

    function setUp() public {
        //Mock calls (currently redundant)
        hevm.mockCall(
            localAnyCallAddress, abi.encodeWithSignature("executor()"), abi.encode(localAnyCallExecutorAddress)
        );

        /////////////////////////////////
        //      Deploy Root Utils      //
        /////////////////////////////////

        arbitrumWrappedNativeToken = address(new WETH());
        avaxWrappedNativeToken = address(new WETH());
        ftmWrappedNativeToken = address(new WETH());

        multicallAddress = address(new Multicall2());

        /////////////////////////////////
        //    Deploy Root Contracts    //
        /////////////////////////////////

        rootPort = new RootPort(rootChainId, arbitrumWrappedNativeToken);

        bridgeAgentFactory = new RootBridgeAgentFactory(
            rootChainId,
            WETH9(arbitrumWrappedNativeToken),
            localAnyCallAddress,
            address(rootPort),
            dao
        );

        rootCoreRouter = new CoreRootRouter(rootChainId, arbitrumWrappedNativeToken, address(rootPort));

        rootMulticallRouter = new MulticallRootRouter(
            rootChainId,
            address(rootPort),
            multicallAddress
        );

        hTokenFactory = new ERC20hTokenRootFactory(rootChainId, address(rootPort));

        /////////////////////////////////
        //  Initialize Root Contracts  //
        /////////////////////////////////

        rootPort.initialize(address(bridgeAgentFactory), address(rootCoreRouter));

        hevm.deal(address(rootPort), 1 ether);
        hevm.prank(address(rootPort));
        WETH(arbitrumWrappedNativeToken).deposit{value: 1 ether}();

        hTokenFactory.initialize(address(rootCoreRouter));

        coreBridgeAgent = RootBridgeAgent(
            payable(RootBridgeAgentFactory(bridgeAgentFactory).createBridgeAgent(address(rootCoreRouter)))
        );

        multicallBridgeAgent = RootBridgeAgent(
            payable(RootBridgeAgentFactory(bridgeAgentFactory).createBridgeAgent(address(rootMulticallRouter)))
        );

        rootCoreRouter.initialize(address(coreBridgeAgent), address(hTokenFactory));

        rootMulticallRouter.initialize(address(multicallBridgeAgent));

        /////////////////////////////////
        //Deploy Local Branch Contracts//
        /////////////////////////////////

        arbitrumPort = new ArbitrumBranchPort(rootChainId, address(rootPort), owner);

        arbitrumMulticallRouter = new BaseBranchRouter();

        arbitrumCoreRouter = new ArbitrumCoreBranchRouter(address(0), address(arbitrumPort));

        arbitrumBranchBridgeAgentFactory = new ArbitrumBranchBridgeAgentFactory(
            rootChainId,
            address(bridgeAgentFactory),
            WETH9(arbitrumWrappedNativeToken),
            localAnyCallAddress,
            localAnyCallExecutorAddress,
            address(arbitrumCoreRouter),
            address(arbitrumPort),
            owner
        );

        arbitrumPort.initialize(address(arbitrumCoreRouter), address(arbitrumBranchBridgeAgentFactory));

        arbitrumBranchBridgeAgentFactory.initialize(address(coreBridgeAgent));
        arbitrumCoreBridgeAgent = ArbitrumBranchBridgeAgent(payable(arbitrumPort.bridgeAgents(0)));

        arbitrumCoreRouter.initialize(address(arbitrumCoreBridgeAgent));
        //arbitrumMulticallRouter.initialize(address(arbitrumMulticallBridgeAgent));

        //////////////////////////////////
        // Deploy Avax Branch Contracts //
        //////////////////////////////////

        avaxPort = new BranchPort(owner);

        avaxHTokenFactory = new ERC20hTokenBranchFactory(rootChainId, address(avaxPort));

        avaxMulticallRouter = new BaseBranchRouter();

        avaxCoreRouter = new CoreBranchRouter(address(avaxHTokenFactory), address(avaxPort));

        avaxBranchBridgeAgentFactory = new BranchBridgeAgentFactory(
            avaxChainId,
            rootChainId,
            address(bridgeAgentFactory),
            WETH9(avaxWrappedNativeToken),
            localAnyCallAddress,
            localAnyCallExecutorAddress,
            address(avaxCoreRouter),
            address(avaxPort),
            owner
        );

        avaxPort.initialize(address(avaxCoreRouter), address(avaxBranchBridgeAgentFactory));

        avaxBranchBridgeAgentFactory.initialize(address(coreBridgeAgent));
        avaxCoreBridgeAgent = BranchBridgeAgent(payable(avaxPort.bridgeAgents(0)));

        avaxHTokenFactory.initialize(avaxWrappedNativeToken, address(avaxCoreRouter));
        avaxLocalWrappedNativeToken = 0x618AEaC155Df3Fd190057af6671482ed7AF4882B;

        avaxCoreRouter.initialize(address(avaxCoreBridgeAgent));

        //////////////////////////////////
        // Deploy Ftm Branch Contracts //
        //////////////////////////////////

        ftmPort = new BranchPort(owner);

        ftmHTokenFactory = new ERC20hTokenBranchFactory(rootChainId, address(ftmPort));

        ftmMulticallRouter = new BaseBranchRouter();

        ftmCoreRouter = new CoreBranchRouter(address(ftmHTokenFactory), address(ftmPort));

        ftmBranchBridgeAgentFactory = new BranchBridgeAgentFactory(
            ftmChainId,
            rootChainId,
            address(bridgeAgentFactory),
            WETH9(ftmWrappedNativeToken),
            localAnyCallAddress,
            localAnyCallExecutorAddress,
            address(ftmCoreRouter),
            address(ftmPort),
            owner
        );

        ftmPort.initialize(address(ftmCoreRouter), address(ftmBranchBridgeAgentFactory));

        ftmBranchBridgeAgentFactory.initialize(address(coreBridgeAgent));
        ftmCoreBridgeAgent = BranchBridgeAgent(payable(ftmPort.bridgeAgents(0)));

        ftmHTokenFactory.initialize(ftmWrappedNativeToken, address(ftmCoreRouter));
        ftmLocalWrappedNativeToken = 0xFb02F4fa07b34d7a3587051169EE9E18D237263C;

        ftmCoreRouter.initialize(address(ftmCoreBridgeAgent));

        /////////////////////////////
        //  Add new branch chains  //
        /////////////////////////////

        avaxGlobalToken = 0xC9CF436b7A143028BAd00f0e5AcD27B945f2e195;

        ftmGlobalToken = 0x852681BcBd7746A111d7Bf9c2601506E6d320554;

        hevm.mockCall(
            nonFungiblePositionManagerAddress,
            abi.encodeWithSignature(
                "createAndInitializePoolIfNecessary(address,address,uint24,uint160)",
                arbitrumWrappedNativeToken,
                avaxGlobalToken,
                uint24(100),
                uint160(200)
            ),
            abi.encode(address(new MockPool(arbitrumWrappedNativeToken,avaxGlobalToken)))
        );

        RootPort(rootPort).addNewChain(
            address(this),
            1 ether,
            address(avaxCoreBridgeAgent),
            avaxChainId,
            "Avalanche",
            "AVAX",
            100,
            50,
            200,
            nonFungiblePositionManagerAddress,
            avaxLocalWrappedNativeToken,
            avaxWrappedNativeToken
        );

        //Mock calls
        hevm.mockCall(
            nonFungiblePositionManagerAddress,
            abi.encodeWithSignature(
                "createAndInitializePoolIfNecessary(address,address,uint24,uint160)",
                arbitrumWrappedNativeToken,
                ftmGlobalToken,
                uint24(100),
                uint160(200)
            ),
            abi.encode(address(new MockPool(arbitrumWrappedNativeToken, ftmGlobalToken)))
        );

        RootPort(rootPort).addNewChain(
            address(this),
            1 ether,
            address(ftmCoreBridgeAgent),
            ftmChainId,
            "Fantom Opera",
            "FTM",
            100,
            50,
            200,
            nonFungiblePositionManagerAddress,
            ftmLocalWrappedNativeToken,
            ftmWrappedNativeToken
        );

        //Ensure there are gas tokens from each chain in the system.
        hevm.startPrank(address(arbitrumPort));
        hevm.deal(address(arbitrumPort), 1 ether);
        WETH9(arbitrumWrappedNativeToken).deposit{value: 1 ether}();
        hevm.stopPrank();

        hevm.startPrank(address(rootPort));
        ERC20hTokenRoot(avaxGlobalToken).mint(address(rootPort), 1 ether, avaxChainId);
        hevm.stopPrank();

        hevm.deal(address(this), 1 ether);
        WETH9(avaxWrappedNativeToken).deposit{value: 1 ether}();
        ERC20hTokenRoot(avaxWrappedNativeToken).transfer(address(avaxPort), 1 ether);

        hevm.startPrank(address(rootPort));
        ERC20hTokenRoot(ftmGlobalToken).mint(address(rootPort), 2 ether, ftmChainId);
        hevm.stopPrank();

        hevm.deal(address(this), 2 ether);
        WETH9(ftmWrappedNativeToken).deposit{value: 2 ether}();
        ERC20hTokenRoot(ftmWrappedNativeToken).transfer(address(ftmPort), 2 ether);

        //////////////////////
        // Verify Addition  //
        //////////////////////

        require(RootPort(rootPort).isGlobalAddress(avaxGlobalToken), "Token should be added");

        require(
            RootPort(rootPort).getGlobalTokenFromLocal(address(avaxLocalWrappedNativeToken), avaxChainId)
                == avaxGlobalToken,
            "Token should be added"
        );

        require(
            RootPort(rootPort).getLocalTokenFromGlobal(avaxGlobalToken, avaxChainId)
                == address(avaxLocalWrappedNativeToken),
            "Token should be added"
        );
        require(
            RootPort(rootPort).getUnderlyingTokenFromLocal(address(avaxLocalWrappedNativeToken), avaxChainId)
                == address(avaxWrappedNativeToken),
            "Token should be added"
        );

        require(
            RootPort(rootPort).getGlobalTokenFromLocal(address(ftmLocalWrappedNativeToken), ftmChainId)
                == ftmGlobalToken,
            "Token should be added"
        );

        require(
            RootPort(rootPort).getLocalTokenFromGlobal(ftmGlobalToken, ftmChainId)
                == address(ftmLocalWrappedNativeToken),
            "Token should be added"
        );
        require(
            RootPort(rootPort).getUnderlyingTokenFromLocal(address(ftmLocalWrappedNativeToken), ftmChainId)
                == address(ftmWrappedNativeToken),
            "Token should be added"
        );

        ///////////////////////////////////
        //  Approve new Branchs in Root  //
        ///////////////////////////////////

        rootPort.initializeCore(address(coreBridgeAgent), address(arbitrumCoreBridgeAgent), address(arbitrumPort));

        multicallBridgeAgent.approveBranchBridgeAgent(rootChainId);

        multicallBridgeAgent.approveBranchBridgeAgent(avaxChainId);

        multicallBridgeAgent.approveBranchBridgeAgent(ftmChainId);

        ///////////////////////////////////////
        //  Add new branches to  Root Agents //
        ///////////////////////////////////////

        hevm.deal(address(this), 3 ether);

        rootCoreRouter.addBranchToBridgeAgent{value: 1 ether}(
            address(multicallBridgeAgent),
            address(avaxBranchBridgeAgentFactory),
            address(avaxMulticallRouter),
            address(avaxCoreRouter),
            avaxChainId,
            0.01 ether
        );

        rootCoreRouter.addBranchToBridgeAgent{value: 1 ether}(
            address(multicallBridgeAgent),
            address(ftmBranchBridgeAgentFactory),
            address(ftmMulticallRouter),
            address(ftmCoreRouter),
            ftmChainId,
            0.5 ether
        );

        rootCoreRouter.addBranchToBridgeAgent(
            address(multicallBridgeAgent),
            address(arbitrumBranchBridgeAgentFactory),
            address(arbitrumMulticallRouter),
            address(arbitrumCoreRouter),
            rootChainId,
            0
        );

        /////////////////////////////////////
        //  Initialize new Branch Routers  //
        /////////////////////////////////////

        arbitrumMulticallBridgeAgent = ArbitrumBranchBridgeAgent(payable(arbitrumPort.bridgeAgents(1)));
        avaxMulticallBridgeAgent = BranchBridgeAgent(payable(avaxPort.bridgeAgents(1)));
        ftmMulticallBridgeAgent = BranchBridgeAgent(payable(ftmPort.bridgeAgents(1)));

        arbitrumMulticallRouter.initialize(address(arbitrumMulticallBridgeAgent));
        avaxMulticallRouter.initialize(address(avaxMulticallBridgeAgent));
        ftmMulticallRouter.initialize(address(ftmMulticallBridgeAgent));

        //////////////////////////////////////
        //Deploy Underlying Tokens and Mocks//
        //////////////////////////////////////

        // avaxMockAssethToken = new MockERC20("hTOKEN-AVAX", "LOCAL hTOKEN FOR TOKEN IN AVAX", 18);
        avaxMockAssetToken = new MockERC20("underlying token", "UNDER", 18);

        // ftmMockAssethToken = new MockERC20("hTOKEN-FTM", "LOCAL hTOKEN FOR TOKEN IN FMT", 18);
        ftmMockAssetToken = new MockERC20("underlying token", "UNDER", 18);

        //arbitrumMockAssethToken is global
        arbitrumMockToken = new MockERC20("underlying token", "UNDER", 18);
    }

    fallback() external payable {}

    struct OutputParams {
        address recipient;
        address outputToken;
        uint256 amountOut;
        uint256 depositOut;
    }

    struct OutputMultipleParams {
        address recipient;
        address[] outputTokens;
        uint256[] amountsOut;
        uint256[] depositsOut;
    }

    //////////////////////////////////////
    //           Bridge Agents          //
    //////////////////////////////////////

    function testAddBridgeAgent() public {
        //Get some gas
        hevm.deal(address(this), 1 ether);

        //Get some gas
        hevm.deal(address(this), 1 ether);

        //Create Root Bridge Agent
        MulticallRootRouter testMulticallRouter = new MulticallRootRouter(
            rootChainId,
            address(rootPort),
            multicallAddress
        );

        // Create Bridge Agent
        RootBridgeAgent testRootBridgeAgent = RootBridgeAgent(
            payable(RootBridgeAgentFactory(bridgeAgentFactory).createBridgeAgent(address(testMulticallRouter)))
        );

        //Initialize Router
        testMulticallRouter.initialize(address(testRootBridgeAgent));

        //Create Branch Router
        BaseBranchRouter ftmTestRouter = new BaseBranchRouter();

        //Allow new branch
        testRootBridgeAgent.approveBranchBridgeAgent(ftmChainId);

        //Create Branch Bridge Agent
        rootCoreRouter.addBranchToBridgeAgent{value: 0.05 ether}(
            address(testRootBridgeAgent),
            address(ftmBranchBridgeAgentFactory),
            address(testMulticallRouter),
            address(ftmCoreRouter),
            ftmChainId,
            0.01 ether
        );

        console2.log("new branch bridge agent", ftmPort.bridgeAgents(2));

        BranchBridgeAgent ftmTestBranchBridgeAgent = BranchBridgeAgent(payable(ftmPort.bridgeAgents(2)));

        ftmTestRouter.initialize(address(ftmTestBranchBridgeAgent));

        require(testRootBridgeAgent.getBranchBridgeAgent(ftmChainId) == address(ftmTestBranchBridgeAgent));
    }

    function testAddBridgeAgentAlreadyAdded() public {
        testAddBridgeAgent();

        //Get some gas
        hevm.deal(address(this), 1 ether);

        RootBridgeAgent testRootBridgeAgent = RootBridgeAgent(payable(rootPort.bridgeAgents(2)));

        hevm.expectRevert(abi.encodeWithSignature("AlreadyAddedBridgeAgent()"));

        //Allow new branch
        testRootBridgeAgent.approveBranchBridgeAgent(ftmChainId);
    }

    function testAddBridgeAgentTwoTimes() public {
        testAddBridgeAgent();

        //Get some gas
        hevm.deal(address(this), 1 ether);

        //Create Root Bridge Agent
        MulticallRootRouter testMulticallRouter = new MulticallRootRouter(
            rootChainId,
            address(rootPort),
            multicallAddress
        );

        RootBridgeAgent testRootBridgeAgent = RootBridgeAgent(payable(rootPort.bridgeAgents(2)));

        hevm.expectRevert(abi.encodeWithSignature("InvalidChainId()"));

        //Create Branch Bridge Agent
        rootCoreRouter.addBranchToBridgeAgent{value: 0.05 ether}(
            address(testRootBridgeAgent),
            address(ftmBranchBridgeAgentFactory),
            address(testMulticallRouter),
            address(ftmCoreRouter),
            ftmChainId,
            0.01 ether
        );
    }

    function testAddBridgeAgentNotApproved() public {
        //Get some gas
        hevm.deal(address(this), 1 ether);

        //Create Root Bridge Agent
        MulticallRootRouter testMulticallRouter = new MulticallRootRouter(
            rootChainId,
            address(rootPort),
            multicallAddress
        );

        // Create Bridge Agent
        RootBridgeAgent testRootBridgeAgent = RootBridgeAgent(
            payable(RootBridgeAgentFactory(bridgeAgentFactory).createBridgeAgent(address(testMulticallRouter)))
        );

        //Initialize Router
        testMulticallRouter.initialize(address(testRootBridgeAgent));

        hevm.expectRevert(abi.encodeWithSignature("UnauthorizedChainId()"));

        //Create Branch Bridge Agent
        rootCoreRouter.addBranchToBridgeAgent{value: 0.05 ether}(
            address(testRootBridgeAgent),
            address(ftmBranchBridgeAgentFactory),
            address(testMulticallRouter),
            address(ftmCoreRouter),
            ftmChainId,
            0.01 ether
        );
    }

    function testAddBridgeAgentNotManager() public {
        //Get some gas
        hevm.deal(address(89), 1 ether);

        //Create Root Bridge Agent
        MulticallRootRouter testMulticallRouter = new MulticallRootRouter(
            rootChainId,
            address(rootPort),
            multicallAddress
        );

        // Create Bridge Agent
        RootBridgeAgent testRootBridgeAgent = RootBridgeAgent(
            payable(RootBridgeAgentFactory(bridgeAgentFactory).createBridgeAgent(address(testMulticallRouter)))
        );

        //Initialize Router
        testMulticallRouter.initialize(address(testRootBridgeAgent));

        hevm.startPrank(address(89));

        hevm.expectRevert(abi.encodeWithSignature("UnauthorizedCallerNotManager()"));
        //Create Branch Bridge Agent
        rootCoreRouter.addBranchToBridgeAgent{value: 0.05 ether}(
            address(testRootBridgeAgent),
            address(ftmBranchBridgeAgentFactory),
            address(testMulticallRouter),
            address(ftmCoreRouter),
            ftmChainId,
            0.01 ether
        );
    }

    function testAddBridgeAgentWrongBranchFactory() public {
        //Get some gas
        hevm.deal(address(this), 1 ether);

        //Create Root Bridge Agent
        MulticallRootRouter testMulticallRouter = new MulticallRootRouter(
            rootChainId,
            address(rootPort),
            multicallAddress
        );

        // Create Bridge Agent
        RootBridgeAgent testRootBridgeAgent = RootBridgeAgent(
            payable(RootBridgeAgentFactory(bridgeAgentFactory).createBridgeAgent(address(testMulticallRouter)))
        );

        //Initialize Router
        testMulticallRouter.initialize(address(testRootBridgeAgent));

        //Allow new branch
        testRootBridgeAgent.approveBranchBridgeAgent(ftmChainId);

        //Create Branch Bridge Agent
        rootCoreRouter.addBranchToBridgeAgent{value: 0.05 ether}(
            address(testRootBridgeAgent),
            address(32),
            address(testMulticallRouter),
            address(ftmCoreRouter),
            ftmChainId,
            0.01 ether
        );

        require(
            RootBridgeAgent(testRootBridgeAgent).getBranchBridgeAgent(ftmChainId) == address(0),
            "Branch Bridge Agent should not be created"
        );
    }

    function testRemoveBridgeAgent() public {
        rootCoreRouter.removeBranchBridgeAgent{value: 0.05 ether}(
            address(ftmMulticallBridgeAgent), address(this), ftmChainId
        );

        require(!ftmPort.isBridgeAgent(address(ftmMulticallBridgeAgent)), "Should be disabled");
    }

    //////////////////////////////////////
    //        Bridge Agent Factory     //
    //////////////////////////////////////

    function testAddBridgeAgentFactory() public {
        //Get some gas
        hevm.deal(address(this), 1 ether);

        BranchBridgeAgentFactory newFtmBranchBridgeAgentFactory = new BranchBridgeAgentFactory(
            ftmChainId,
            rootChainId,
            address(80),
            WETH9(ftmWrappedNativeToken),
            localAnyCallAddress,
            localAnyCallExecutorAddress,
            address(ftmCoreRouter),
            address(ftmPort),
            owner
        );

        console2.log("Core Router Owner", rootCoreRouter.owner());

        rootCoreRouter.toggleBranchBridgeAgentFactory{value: 0.05 ether}(
            address(bridgeAgentFactory), address(newFtmBranchBridgeAgentFactory), address(this), ftmChainId
        );

        require(ftmPort.isBridgeAgentFactory(address(newFtmBranchBridgeAgentFactory)), "Factory not enabled");
    }

    function testAddBridgeAgentWrongRootFactory() public {
        testAddBridgeAgentFactory();

        //Get some gas
        hevm.deal(address(this), 1 ether);

        //Create Root Bridge Agent
        MulticallRootRouter testMulticallRouter = new MulticallRootRouter(
            rootChainId,
            address(rootPort),
            multicallAddress
        );

        // Create Bridge Agent
        RootBridgeAgent testRootBridgeAgent = RootBridgeAgent(
            payable(RootBridgeAgentFactory(bridgeAgentFactory).createBridgeAgent(address(testMulticallRouter)))
        );

        //Initialize Router
        testMulticallRouter.initialize(address(testRootBridgeAgent));

        //Allow new branch
        testRootBridgeAgent.approveBranchBridgeAgent(ftmChainId);

        //Create Branch Bridge Agent
        rootCoreRouter.addBranchToBridgeAgent{value: 0.05 ether}(
            address(testRootBridgeAgent),
            ftmPort.bridgeAgentFactories(1),
            address(testMulticallRouter),
            address(ftmCoreRouter),
            ftmChainId,
            0.01 ether
        );

        require(
            RootBridgeAgent(testRootBridgeAgent).getBranchBridgeAgent(ftmChainId) == address(0),
            "Branch Bridge Agent should not be created"
        );
    }

    function testRemoveBridgeAgentFactory() public {
        //Add Factory
        testAddBridgeAgentFactory();

        //Get some gas
        hevm.deal(address(this), 1 ether);

        rootCoreRouter.toggleBranchBridgeAgentFactory{value: 0.05 ether}(
            address(bridgeAgentFactory), ftmPort.bridgeAgentFactories(1), address(this), ftmChainId
        );

        require(!ftmPort.isBridgeAgentFactory(ftmPort.bridgeAgentFactories(1)), "Should be disabled");
    }

    //////////////////////////////////////
    //           Port Strategies        //
    //////////////////////////////////////

    function testAddStrategyToken() public {
        //Get some gas
        hevm.deal(address(this), 1 ether);

        rootCoreRouter.manageStrategyToken{value: 0.05 ether}(address(102), 300, address(this), ftmChainId);

        require(ftmPort.isStrategyToken(address(102)), "Should be added");
    }

    function testAddStrategyTokenInvalidMinReserve() public {
        //Get some gas
        hevm.deal(address(this), 1 ether);

        // hevm.expectRevert(abi.encodeWithSignature("InvalidMinimumReservesRatio()"));
        rootCoreRouter.manageStrategyToken{value: 0.05 ether}(address(102), 30000, address(this), ftmChainId);
        require(!ftmPort.isStrategyToken(address(102)), "Should note be added");
    }

    function testRemoveStrategyToken() public {
        //Add Token
        testAddStrategyToken();

        //Get some gas
        hevm.deal(address(this), 1 ether);

        rootCoreRouter.manageStrategyToken{value: 0.05 ether}(address(102), 0, address(this), ftmChainId);

        require(!ftmPort.isStrategyToken(address(102)), "Should be removed");
    }

    function testAddPortStrategy() public {
        //Add strategy token
        testAddStrategyToken();

        //Get some gas
        hevm.deal(address(this), 1 ether);

        rootCoreRouter.managePortStrategy{value: 0.05 ether}(
            address(50), address(102), 300, false, address(this), ftmChainId
        );

        require(ftmPort.isPortStrategy(address(50), address(102)), "Should be added");
    }

    function testAddPortStrategyNotToken() public {
        //Get some gas
        hevm.deal(address(this), 1 ether);

        //UnrecognizedStrategyToken();
        rootCoreRouter.managePortStrategy{value: 0.05 ether}(
            address(50), address(102), 300, false, address(this), ftmChainId
        );

        require(!ftmPort.isPortStrategy(address(50), address(102)), "Should not be added");
    }

    //////////////////////////////////////
    //          TOKEN MANAGEMENT        //
    //////////////////////////////////////

    address public newAvaxAssetGlobalAddress;

    function testAddLocalToken() public {
        hevm.deal(address(this), 1 ether);

        avaxCoreRouter.addLocalToken{value: 0.00005 ether}(address(avaxMockAssetToken));

        avaxMockAssethToken = RootPort(rootPort).getLocalTokenFromUnder(address(avaxMockAssetToken), avaxChainId);

        newAvaxAssetGlobalAddress = RootPort(rootPort).getGlobalTokenFromLocal(avaxMockAssethToken, avaxChainId);

        console2.log("New Global: ", newAvaxAssetGlobalAddress);
        console2.log("New Local: ", avaxMockAssethToken);

        require(
            RootPort(rootPort).getGlobalTokenFromLocal(avaxMockAssethToken, avaxChainId) == newAvaxAssetGlobalAddress,
            "Token should be added"
        );
        require(
            RootPort(rootPort).getLocalTokenFromGlobal(newAvaxAssetGlobalAddress, avaxChainId) == avaxMockAssethToken,
            "Token should be added"
        );
        require(
            RootPort(rootPort).getUnderlyingTokenFromLocal(avaxMockAssethToken, avaxChainId)
                == address(avaxMockAssetToken),
            "Token should be added"
        );
    }

    address public newFtmAssetGlobalAddress;

    address public newAvaxAssetLocalToken;

    function testAddGlobalToken() public {
        //Add Local Token from Avax
        testAddLocalToken();

        avaxCoreRouter.addGlobalToken{value: 0.05 ether}(
            newAvaxAssetGlobalAddress, ftmChainId, 0.000025 ether, 0.00001 ether
        );

        newAvaxAssetLocalToken = RootPort(rootPort).getLocalTokenFromGlobal(newAvaxAssetGlobalAddress, ftmChainId);

        console2.log("New Local: ", newAvaxAssetLocalToken);

        require(
            RootPort(rootPort).getLocalTokenFromGlobal(newAvaxAssetGlobalAddress, ftmChainId) == newAvaxAssetLocalToken,
            "Token should be added"
        );

        require(
            RootPort(rootPort).getUnderlyingTokenFromLocal(newAvaxAssetLocalToken, ftmChainId) == address(0),
            "Underlying should not be added"
        );
    }

    address public mockApp = address(0xDAFA);

    address public newArbitrumAssetGlobalAddress;

    function testAddLocalTokenArbitrum() public {
        //Set up
        testAddGlobalToken();

        //Get some gas.
        hevm.deal(address(this), 1 ether);

        //Add new localToken
        arbitrumCoreRouter.addLocalToken{value: 0.0005 ether}(address(arbitrumMockToken));

        newArbitrumAssetGlobalAddress =
            RootPort(rootPort).getLocalTokenFromUnder(address(arbitrumMockToken), rootChainId);

        console2.log("New: ", newArbitrumAssetGlobalAddress);

        require(
            RootPort(rootPort).getGlobalTokenFromLocal(address(newArbitrumAssetGlobalAddress), rootChainId)
                == address(newArbitrumAssetGlobalAddress),
            "Token should be added"
        );
        require(
            RootPort(rootPort).getLocalTokenFromGlobal(newArbitrumAssetGlobalAddress, rootChainId)
                == address(newArbitrumAssetGlobalAddress),
            "Token should be added"
        );
        require(
            RootPort(rootPort).getUnderlyingTokenFromLocal(address(newArbitrumAssetGlobalAddress), rootChainId)
                == address(arbitrumMockToken),
            "Token should be added"
        );
    }

    //////////////////////////////////////
    //          TOKEN TRANSFERS         //
    //////////////////////////////////////

    function testCallOutWithDeposit() public {
        //Set up
        testAddLocalTokenArbitrum();

        //Prepare data
        address outputToken;
        uint256 amountOut;
        uint256 depositOut;
        bytes memory packedData;

        {
            outputToken = newArbitrumAssetGlobalAddress;
            amountOut = 100 ether;
            depositOut = 50 ether;

            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            //Mock action
            calls[0] = Multicall2.Call({target: 0x0000000000000000000000000000000000000000, callData: ""});

            //Output Params
            OutputParams memory outputParams = OutputParams(address(this), outputToken, amountOut, depositOut);

            //toChain
            uint24 toChain = rootChainId;

            //RLP Encode Calldata
            bytes memory data = abi.encode(calls, outputParams, toChain);

            //Pack FuncId
            packedData = abi.encodePacked(bytes1(0x02), data);
        }

        //Get some gas.
        hevm.deal(address(this), 1 ether);

        //Mint Underlying Token.
        arbitrumMockToken.mint(address(this), 100 ether);

        //Approve spend by router
        arbitrumMockToken.approve(address(arbitrumPort), 100 ether);

        //Prepare deposit info
        DepositInput memory depositInput = DepositInput({
            hToken: address(newArbitrumAssetGlobalAddress),
            token: address(arbitrumMockToken),
            amount: 100 ether,
            deposit: 100 ether,
            toChain: rootChainId
        });

        //Call Deposit function
        arbitrumMulticallBridgeAgent.callOutSignedAndBridge{value: 1 ether}(packedData, depositInput, 0.5 ether);

        // Test If Deposit was successful
        testCreateDepositSingle(
            arbitrumMulticallBridgeAgent,
            uint32(1),
            address(this),
            address(newArbitrumAssetGlobalAddress),
            address(arbitrumMockToken),
            100 ether,
            100 ether,
            1 ether,
            0.5 ether
        );

        console2.log("LocalPort Balance:", MockERC20(arbitrumMockToken).balanceOf(address(arbitrumPort)));
        require(
            MockERC20(arbitrumMockToken).balanceOf(address(arbitrumPort)) == 50 ether, "LocalPort should have 50 tokens"
        );

        console2.log("User Balance:", MockERC20(arbitrumMockToken).balanceOf(address(this)));
        require(MockERC20(arbitrumMockToken).balanceOf(address(this)) == 50 ether, "User should have 50 tokens");

        console2.log("User Global Balance:", MockERC20(newArbitrumAssetGlobalAddress).balanceOf(address(this)));
        require(
            MockERC20(newArbitrumAssetGlobalAddress).balanceOf(address(this)) == 50 ether,
            "User should have 50 global tokens"
        );
    }

    function testFuzzCallOutWithDeposit(
        address _user,
        uint256 _amount,
        uint256 _deposit,
        uint256 _amountOut,
        uint256 _depositOut
    ) public {
        // Input restrictions
        // hevm.assume(_user != address(0) && _amount > 0 && _amount > _deposit);
        hevm.assume(
            _user != address(0) && _amount > 0 && _amount > _deposit && _amount >= _amountOut
                && _amount - _amountOut >= _depositOut && _depositOut < _amountOut
        );

        //Set up
        testAddLocalTokenArbitrum();

        //Prepare data
        bytes memory packedData;

        {
            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            //Mock Omnichain dApp call
            calls[0] = Multicall2.Call({target: 0x0000000000000000000000000000000000000000, callData: ""});

            //Output Params
            OutputParams memory outputParams =
                OutputParams(_user, newArbitrumAssetGlobalAddress, _amountOut, _depositOut);

            //RLP Encode Calldata
            bytes memory data = abi.encode(calls, outputParams, rootChainId);

            //Pack FuncId
            packedData = abi.encodePacked(bytes1(0x02), data);
        }

        //Get some gas.
        hevm.deal(_user, 1 ether);

        if (_amount - _deposit > 0) {
            //assure there is enough balance for mock action
            hevm.startPrank(address(rootPort));
            ERC20hTokenRoot(newArbitrumAssetGlobalAddress).mint(_user, _amount - _deposit, rootChainId);
            hevm.stopPrank();
            arbitrumMockToken.mint(address(arbitrumPort), _amount - _deposit);
        }

        //Mint Underlying Token.
        if (_deposit > 0) arbitrumMockToken.mint(_user, _deposit);

        //Prepare deposit info
        DepositInput memory depositInput = DepositInput({
            hToken: address(newArbitrumAssetGlobalAddress),
            token: address(arbitrumMockToken),
            amount: _amount,
            deposit: _deposit,
            toChain: rootChainId
        });

        console2.log("BALANCE BEFORE:");
        console2.log("arbitrumMockToken Balance:", MockERC20(arbitrumMockToken).balanceOf(_user));
        console2.log(
            "newArbitrumAssetGlobalAddress Balance:", MockERC20(newArbitrumAssetGlobalAddress).balanceOf(_user)
        );

        //Call Deposit function
        hevm.startPrank(_user);
        arbitrumMockToken.approve(address(arbitrumPort), _deposit);
        ERC20hTokenRoot(newArbitrumAssetGlobalAddress).approve(address(rootPort), _amount - _deposit);
        arbitrumMulticallBridgeAgent.callOutSignedAndBridge{value: 1 ether}(packedData, depositInput, 0.5 ether);
        hevm.stopPrank();

        // Test If Deposit was successful
        testCreateDepositSingle(
            arbitrumMulticallBridgeAgent,
            uint32(1),
            _user,
            address(newArbitrumAssetGlobalAddress),
            address(arbitrumMockToken),
            _amount,
            _deposit,
            1 ether,
            0 ether
        );

        console2.log("DATA");
        console2.log(_amount);
        console2.log(_deposit);
        console2.log(_amountOut);
        console2.log(_depositOut);

        address userAccount = address(RootPort(rootPort).getUserAccount(_user));

        console2.log("LocalPort Balance:", MockERC20(arbitrumMockToken).balanceOf(address(arbitrumPort)));
        console2.log("Expected:", _amount - _deposit + _deposit - _depositOut);
        require(
            MockERC20(arbitrumMockToken).balanceOf(address(arbitrumPort)) == _amount - _deposit + _deposit - _depositOut,
            "LocalPort tokens"
        );

        console2.log("RootPort Balance:", MockERC20(newArbitrumAssetGlobalAddress).balanceOf(address(rootPort)));
        // console2.log("Expected:", 0); SINCE ORIGIN == DESTINATION == ARBITRUM
        require(MockERC20(newArbitrumAssetGlobalAddress).balanceOf(address(rootPort)) == 0, "RootPort tokens");

        console2.log("User Balance:", MockERC20(arbitrumMockToken).balanceOf(_user));
        console2.log("Expected:", _depositOut);
        require(MockERC20(arbitrumMockToken).balanceOf(_user) == _depositOut, "User tokens");

        console2.log("User Global Balance:", MockERC20(newArbitrumAssetGlobalAddress).balanceOf(_user));
        console2.log("Expected:", _amountOut - _depositOut);
        require(
            MockERC20(newArbitrumAssetGlobalAddress).balanceOf(_user) == _amountOut - _depositOut, "User Global tokens"
        );

        console2.log("User Account Balance:", MockERC20(newArbitrumAssetGlobalAddress).balanceOf(userAccount));
        console2.log("Expected:", _amount - _amountOut);
        require(
            MockERC20(newArbitrumAssetGlobalAddress).balanceOf(userAccount) == _amount - _amountOut,
            "User Account tokens"
        );
    }

    function testRetrySettlement() public {
        //Set up
        testAddLocalTokenArbitrum();

        //Prepare data
        bytes memory packedData;

        {
            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            //Mock action
            calls[0] = Multicall2.Call({target: 0x0000000000000000000000000000000000000000, callData: ""});

            //Output Params
            OutputParams memory outputParams = OutputParams(address(this), newAvaxAssetGlobalAddress, 150 ether, 0);

            //RLP Encode Calldata Call with no gas to bridge out and we top up.
            bytes memory data = abi.encode(calls, outputParams, ftmChainId);

            //Pack FuncId
            packedData = abi.encodePacked(bytes1(0x02), data);
        }

        address _user = address(this);

        //Get some gas.
        hevm.deal(_user, 1 ether);
        hevm.deal(address(ftmPort), 1 ether);

        //assure there is enough balance for mock action
        hevm.prank(address(rootPort));
        ERC20hTokenRoot(newAvaxAssetGlobalAddress).mint(address(rootPort), 50 ether, rootChainId);
        hevm.prank(address(avaxPort));
        ERC20hTokenBranch(avaxMockAssethToken).mint(_user, 50 ether);

        //Mint Underlying Token.
        avaxMockAssetToken.mint(_user, 100 ether);

        //Prepare deposit info
        DepositInput memory depositInput = DepositInput({
            hToken: address(avaxMockAssethToken),
            token: address(avaxMockAssetToken),
            amount: 150 ether,
            deposit: 100 ether,
            toChain: ftmChainId
        });

        console2.log("BALANCE BEFORE:");
        console2.log("User avaxMockAssetToken Balance:", MockERC20(avaxMockAssetToken).balanceOf(_user));
        console2.log("User avaxMockAssethToken Balance:", MockERC20(avaxMockAssethToken).balanceOf(_user));

        //Set MockAnycall AnyFallback mode ON
        MockAnycall(localAnyCallAddress).toggleFallback(1);

        //Call Deposit function
        avaxMockAssetToken.approve(address(avaxPort), 100 ether);
        ERC20hTokenRoot(avaxMockAssethToken).approve(address(avaxPort), 50 ether);
        avaxMulticallBridgeAgent.callOutSignedAndBridge{value: 1 ether}(packedData, depositInput, 0.5 ether);

        //Set MockAnycall AnyFallback mode OFF
        MockAnycall(localAnyCallAddress).toggleFallback(0);

        //Perform anyFallback transaction back to root bridge agent
        MockAnycall(localAnyCallAddress).testFallback();

        uint256 _amount = 150 ether;
        uint256 _deposit = 100 ether;
        uint256 _amountOut = 150 ether;
        uint256 _depositOut = 150 ether;
        console2.log("DATA");
        console2.log(_amount);
        console2.log(_deposit);
        console2.log(_amountOut);
        console2.log(_depositOut);

        uint32 settlementNonce = multicallBridgeAgent.settlementNonce() - 1;

        Settlement memory settlement = multicallBridgeAgent.getSettlementEntry(settlementNonce);

        console2.log("Status after fallback:", settlement.status == SettlementStatus.Failed ? "Failed" : "Success");

        require(settlement.status == SettlementStatus.Failed, "Settlement status should be failed.");

        //Get some gas.
        hevm.deal(_user, 1 ether);

        //Retry Settlement
        multicallBridgeAgent.retrySettlement{value: 1 ether}(settlementNonce, 0.5 ether);

        settlement = multicallBridgeAgent.getSettlementEntry(settlementNonce);

        require(settlement.status == SettlementStatus.Success, "Settlement status should be success.");
    }

    function testRedeemSettlement() public {
        //Set up
        testAddLocalTokenArbitrum();

        //Prepare data
        bytes memory packedData;

        {
            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            //Mock action
            calls[0] = Multicall2.Call({target: 0x0000000000000000000000000000000000000000, callData: ""});

            //Output Params
            OutputParams memory outputParams = OutputParams(address(this), newAvaxAssetGlobalAddress, 150 ether, 0);

            //RLP Encode Calldata Call with no gas to bridge out and we top up.
            bytes memory data = abi.encode(calls, outputParams, ftmChainId);

            //Pack FuncId
            packedData = abi.encodePacked(bytes1(0x02), data);
        }

        address _user = address(this);

        //Get some gas.
        hevm.deal(_user, 1 ether);
        hevm.deal(address(ftmPort), 1 ether);

        //assure there is enough balance for mock action
        hevm.prank(address(rootPort));
        ERC20hTokenRoot(newAvaxAssetGlobalAddress).mint(address(rootPort), 50 ether, rootChainId);
        hevm.prank(address(avaxPort));
        ERC20hTokenBranch(avaxMockAssethToken).mint(_user, 50 ether);

        //Mint Underlying Token.
        avaxMockAssetToken.mint(_user, 100 ether);

        //Prepare deposit info
        DepositInput memory depositInput = DepositInput({
            hToken: address(avaxMockAssethToken),
            token: address(avaxMockAssetToken),
            amount: 150 ether,
            deposit: 100 ether,
            toChain: ftmChainId
        });

        console2.log("BALANCE BEFORE:");
        console2.log("User avaxMockAssetToken Balance:", MockERC20(avaxMockAssetToken).balanceOf(_user));
        console2.log("User avaxMockAssethToken Balance:", MockERC20(avaxMockAssethToken).balanceOf(_user));

        //Set MockAnycall AnyFallback mode ON
        MockAnycall(localAnyCallAddress).toggleFallback(1);

        //Call Deposit function
        avaxMockAssetToken.approve(address(avaxPort), 100 ether);
        ERC20hTokenRoot(avaxMockAssethToken).approve(address(avaxPort), 50 ether);
        avaxMulticallBridgeAgent.callOutSignedAndBridge{value: 1 ether}(packedData, depositInput, 0.5 ether);

        //Set MockAnycall AnyFallback mode OFF
        MockAnycall(localAnyCallAddress).toggleFallback(0);

        //Perform anyFallback transaction back to root bridge agent
        MockAnycall(localAnyCallAddress).testFallback();

        uint256 _amount = 150 ether;
        uint256 _deposit = 100 ether;
        uint256 _amountOut = 150 ether;
        uint256 _depositOut = 150 ether;
        console2.log("DATA");
        console2.log(_amount);
        console2.log(_deposit);
        console2.log(_amountOut);
        console2.log(_depositOut);

        uint32 settlementNonce = multicallBridgeAgent.settlementNonce() - 1;

        Settlement memory settlement = multicallBridgeAgent.getSettlementEntry(settlementNonce);

        console2.log("Status after fallback:", settlement.status == SettlementStatus.Failed ? "Failed" : "Success");

        require(settlement.status == SettlementStatus.Failed, "Settlement status should be failed.");

        //Retry Settlement
        multicallBridgeAgent.redeemSettlement(settlementNonce);

        settlement = multicallBridgeAgent.getSettlementEntry(settlementNonce);

        require(settlement.owner == address(0), "Settlement should cease to exist.");

        require(
            MockERC20(newAvaxAssetGlobalAddress).balanceOf(_user) == 150 ether, "Settlement should have been redeemed"
        );
    }

    //////////////////////////////////////////////////////////////////////////   HELPERS   ///////////////////////////////////////////////////////////////////

    function testCreateDepositSingle(
        ArbitrumBranchBridgeAgent _bridgeAgent,
        uint32 _depositNonce,
        address _user,
        address _hToken,
        address _token,
        uint256 _amount,
        uint256 _deposit,
        uint128,
        uint128
    ) private view {
        // Cast to Dynamic TODO clean up
        address[] memory hTokens = new address[](1);
        hTokens[0] = _hToken;
        address[] memory tokens = new address[](1);
        tokens[0] = _token;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _amount;
        uint256[] memory deposits = new uint256[](1);
        deposits[0] = _deposit;

        // Get Deposit
        Deposit memory deposit = _bridgeAgent.getDepositEntry(_depositNonce);

        console2.logUint(1);
        console2.log(deposit.hTokens[0], hTokens[0]);
        console2.log(deposit.tokens[0], tokens[0]);

        // Check deposit
        require(deposit.owner == _user, "Deposit owner doesn't match");

        require(
            keccak256(abi.encodePacked(deposit.hTokens)) == keccak256(abi.encodePacked(hTokens)),
            "Deposit local hToken doesn't match"
        );
        require(
            keccak256(abi.encodePacked(deposit.tokens)) == keccak256(abi.encodePacked(tokens)),
            "Deposit underlying token doesn't match"
        );
        require(
            keccak256(abi.encodePacked(deposit.amounts)) == keccak256(abi.encodePacked(amounts)),
            "Deposit amount doesn't match"
        );
        require(
            keccak256(abi.encodePacked(deposit.deposits)) == keccak256(abi.encodePacked(deposits)),
            "Deposit deposit doesn't match"
        );

        require(deposit.status == DepositStatus.Success, "Deposit status should be succesful.");

        console2.log("TEST DEPOSIT~");
        console2.logUint(deposit.depositedGas);
        console2.logUint(WETH9(arbitrumWrappedNativeToken).balanceOf(address(arbitrumPort)));
    }

    function encodeSystemCall(
        address payable _fromBridgeAgent,
        address payable _toBridgeAgent,
        uint32 _nonce,
        bytes memory _data,
        uint128 _rootExecGas,
        uint128 _remoteExecGas,
        uint24 _fromChainId
    ) private {
        // Mock anycall context
        hevm.mockCall(
            localAnyCallExecutorAddress,
            abi.encodeWithSignature("context()"),
            abi.encode(_fromBridgeAgent, _fromChainId, 22)
        );

        //Encode Data
        bytes memory inputCalldata = abi.encodePacked(bytes1(0x00), _nonce, _data, _rootExecGas, _remoteExecGas);

        hevm.mockCall(
            address(localAnyConfig),
            abi.encodeWithSignature(
                "calcSrcFees(address,uint256,uint256)", address(0), _fromChainId, inputCalldata.length
            ),
            abi.encode(0)
        );

        // Prank into user account
        hevm.startPrank(localAnyCallExecutorAddress);

        //Call Deposit function
        RootBridgeAgent(_toBridgeAgent).anyExecute(inputCalldata);

        // Prank out of user account
        hevm.stopPrank();
    }

    function encodeCallNoDeposit(
        address payable _fromBridgeAgent,
        address payable _toBridgeAgent,
        uint32 _nonce,
        bytes memory _data,
        uint128 _rootExecGas,
        uint128 _remoteExecGas,
        uint24 _fromChainId
    ) private {
        // Mock anycall context
        hevm.mockCall(
            localAnyCallExecutorAddress,
            abi.encodeWithSignature("context()"),
            abi.encode(_fromBridgeAgent, _fromChainId, 22)
        );

        //Encode Data
        bytes memory inputCalldata = abi.encodePacked(bytes1(0x01), _nonce, _data, _rootExecGas, _remoteExecGas);

        hevm.mockCall(
            address(localAnyConfig),
            abi.encodeWithSignature(
                "calcSrcFees(address,uint256,uint256)", address(0), _fromChainId, inputCalldata.length
            ),
            abi.encode(0)
        );

        // Prank into user account
        hevm.startPrank(localAnyCallExecutorAddress);

        //Call Deposit function
        RootBridgeAgent(_toBridgeAgent).anyExecute(inputCalldata);

        // Prank out of user account
        hevm.stopPrank();
    }

    function encodeCallNoDepositSigned(
        address payable _fromBridgeAgent,
        address payable _toBridgeAgent,
        uint32 _nonce,
        address _user,
        bytes memory _data,
        uint128 _rootExecGas,
        uint128 _remoteExecGas,
        uint24 _fromChainId
    ) private {
        // Mock anycall context
        hevm.mockCall(
            localAnyCallExecutorAddress,
            abi.encodeWithSignature("context()"),
            abi.encode(_fromBridgeAgent, _fromChainId, 22)
        );

        //Encode Data
        bytes memory inputCalldata = abi.encodePacked(bytes1(0x04), _user, _nonce, _data, _rootExecGas, _remoteExecGas);

        hevm.mockCall(
            address(localAnyConfig),
            abi.encodeWithSignature(
                "calcSrcFees(address,uint256,uint256)", address(0), _fromChainId, inputCalldata.length
            ),
            abi.encode(0)
        );

        // Prank into user account
        hevm.startPrank(localAnyCallExecutorAddress);

        //Call Deposit function
        RootBridgeAgent(_toBridgeAgent).anyExecute(inputCalldata);

        // Prank out of user account
        hevm.stopPrank();
    }

    function encodeCallWithDeposit(
        address payable _fromBridgeAgent,
        address payable _toBridgeAgent,
        uint24 _fromChainId,
        bytes memory _packedData
    ) private {
        // Mock anycall context
        hevm.mockCall(
            localAnyCallExecutorAddress,
            abi.encodeWithSignature("context()"),
            abi.encode(_fromBridgeAgent, _fromChainId, 22)
        );

        hevm.mockCall(
            address(localAnyConfig),
            abi.encodeWithSignature(
                "calcSrcFees(address,uint256,uint256)", address(0), _fromChainId, _packedData.length
            ),
            abi.encode(0)
        );

        // Prank into user account
        hevm.startPrank(localAnyCallExecutorAddress);

        //Call Deposit function
        RootBridgeAgent(_toBridgeAgent).anyExecute(_packedData);

        // Prank out of user account
        hevm.stopPrank();
    }

    function encodeCallWithDepositMultiple(
        address payable _fromBridgeAgent,
        address payable _toBridgeAgent,
        uint24 _fromChainId,
        bytes memory _packedData
    ) private {
        // Mock anycall context
        hevm.mockCall(
            localAnyCallExecutorAddress,
            abi.encodeWithSignature("context()"),
            abi.encode(_fromBridgeAgent, _fromChainId, 22)
        );

        hevm.mockCall(
            address(localAnyConfig),
            abi.encodeWithSignature(
                "calcSrcFees(address,uint256,uint256)", address(0), _fromChainId, _packedData.length
            ),
            abi.encode(0)
        );

        // Prank into user account
        hevm.startPrank(localAnyCallExecutorAddress);

        //Call Deposit function
        RootBridgeAgent(_toBridgeAgent).anyExecute(_packedData);

        // Prank out of user account
        hevm.stopPrank();
    }

    function _encodeSystemCall(uint32 _nonce, bytes memory _data, uint128 _rootExecGas, uint128 _remoteExecGas)
        internal
        pure
        returns (bytes memory inputCalldata)
    {
        //Encode Data
        inputCalldata = abi.encodePacked(bytes1(0x00), _nonce, _data, _rootExecGas, _remoteExecGas);
    }

    function _encodeNoDeposit(uint32 _nonce, bytes memory _data, uint128 _rootExecGas, uint128 _remoteExecGas)
        internal
        pure
        returns (bytes memory inputCalldata)
    {
        //Encode Data
        inputCalldata = abi.encodePacked(bytes1(0x01), _nonce, _data, _rootExecGas, _remoteExecGas);
    }

    function _encodeNoDepositSigned(
        uint32 _nonce,
        address _user,
        bytes memory _data,
        uint128 _rootExecGas,
        uint128 _remoteExecGas
    ) internal pure returns (bytes memory inputCalldata) {
        //Encode Data
        inputCalldata = abi.encodePacked(bytes1(0x04), _user, _nonce, _data, _rootExecGas, _remoteExecGas);
    }

    function _encode(
        uint32 _nonce,
        address _hToken,
        address _token,
        uint256 _amount,
        uint256 _deposit,
        uint24 _toChain,
        bytes memory _data,
        uint128 _rootExecGas,
        uint128 _remoteExecGas
    ) internal pure returns (bytes memory inputCalldata) {
        //Encode Data
        inputCalldata = abi.encodePacked(
            bytes1(0x02), _nonce, _hToken, _token, _amount, _deposit, _toChain, _data, _rootExecGas, _remoteExecGas
        );
    }

    function _encodeSigned(
        uint32 _nonce,
        address _user,
        address _hToken,
        address _token,
        uint256 _amount,
        uint256 _deposit,
        uint24 _toChain,
        bytes memory _data,
        uint128 _rootExecGas,
        uint128 _remoteExecGas
    ) internal pure returns (bytes memory inputCalldata) {
        //Encode Data
        inputCalldata = abi.encodePacked(
            bytes1(0x05),
            _user,
            _nonce,
            _hToken,
            _token,
            _amount,
            _deposit,
            _toChain,
            _data,
            _rootExecGas,
            _remoteExecGas
        );
    }

    function _encodeMultiple(
        uint32 _nonce,
        address[] memory _hTokens,
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256[] memory _deposits,
        uint24 _toChain,
        bytes memory _data,
        uint128 _rootExecGas,
        uint128 _remoteExecGas
    ) internal pure returns (bytes memory inputCalldata) {
        //Encode Data
        inputCalldata = abi.encodePacked(
            bytes1(0x03),
            uint8(_hTokens.length),
            _nonce,
            _hTokens,
            _tokens,
            _amounts,
            _deposits,
            _toChain,
            _data,
            _rootExecGas,
            _remoteExecGas
        );
    }

    function _encodeMultipleSigned(
        uint32 _nonce,
        address _user,
        address[] memory _hTokens,
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256[] memory _deposits,
        uint24 _toChain,
        bytes memory _data,
        uint128 _rootExecGas,
        uint128 _remoteExecGas
    ) internal pure returns (bytes memory inputCalldata) {
        //Encode Data
        inputCalldata = abi.encodePacked(
            bytes1(0x06),
            _user,
            uint8(_hTokens.length),
            _nonce,
            _hTokens,
            _tokens,
            _amounts,
            _deposits,
            _toChain,
            _data,
            _rootExecGas,
            _remoteExecGas
        );
    }

    function compareDynamicArrays(bytes memory a, bytes memory b) public pure returns (bool aEqualsB) {
        assembly {
            aEqualsB := eq(a, b)
        }
    }
}

contract MockAnycall is DSTestPlus {
    uint256 constant rootChain = 42161;

    address public lastFrom;
    address public anyConfig;
    address public to;
    bytes public data;
    bool forceFallback;
    uint256 fallbackCountdown;

    constructor(address _anyConfig) {
        anyConfig = _anyConfig;
    }

    function toggleFallback(uint256 _fallbackCountdown) external {
        forceFallback = !forceFallback;
        fallbackCountdown = _fallbackCountdown;
    }

    function executor() external pure returns (address) {
        return address(0xABFD);
    }

    function config() external view returns (address) {
        return anyConfig;
    }

    function testFallback() public {
        console2.log("Mocking anyfallback...");
        console2.log("to:", lastFrom);
        console2.log("fromChain:", BranchBridgeAgent(payable(to)).localChainId());

        // Mock anycall context
        hevm.mockCall(
            address(0xABFD),
            abi.encodeWithSignature("context()"),
            abi.encode(address(to), BranchBridgeAgent(payable(to)).localChainId(), 22)
        );

        hevm.prank(address(0xABFD));
        IAnycallApp(lastFrom).anyFallback(data);
    }

    function anyCall(address _to, bytes calldata _data, uint256, uint256, bytes calldata) external payable {
        lastFrom = msg.sender;
        to = _to;
        data = _data;

        console2.log("Mocking anycall...");
        console2.log("from:", lastFrom);
        console2.log("fromChain:", BranchBridgeAgent(payable(msg.sender)).localChainId());

        // Mock anycall context
        hevm.mockCall(
            address(0xABFD),
            abi.encodeWithSignature("context()"),
            abi.encode(address(msg.sender), BranchBridgeAgent(payable(msg.sender)).localChainId(), 22)
        );

        if (!forceFallback) {
            hevm.prank(address(0xABFD));
            IAnycallApp(_to).anyExecute(_data);
        } else {
            if (fallbackCountdown > 0) {
                console2.log("Execute anycall request...", fallbackCountdown--);
                hevm.prank(address(0xABFD));
                IAnycallApp(_to).anyExecute(_data);
            }
        }
    }

    function anyCall(string calldata _to, bytes calldata _data, uint256, uint256, bytes calldata) external payable {
        lastFrom = msg.sender;

        hevm.prank(address(0xABFD));
        IAnycallApp(address(bytes20(bytes(_to)))).anyExecute(_data);
    }
}

contract MockAnyConfig {
    uint256 _executionBudget;

    function deposit(address) external payable {
        emit PaidGas(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        emit RemovedGas(msg.sender, amount);
    }

    function executionBudget(address) public view returns (uint256) {
        return 0.1 ether + address(this).balance;
    }

    event PaidGas(address indexed user, uint256 gas);
    event RemovedGas(address indexed user, uint256 gas);
}

interface IUniswapV3SwapCallback {
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata _data) external;
}

contract MockPool is Test {
    struct SwapCallbackData {
        address tokenIn;
    }

    address arbitrumWrappedNativeTokenAddress;
    address globalGasToken;

    constructor(address _arbitrumWrappedNativeTokenAddress, address _globalGasToken) {
        arbitrumWrappedNativeTokenAddress = _arbitrumWrappedNativeTokenAddress;
        globalGasToken = _globalGasToken;
    }

    function swap(address, bool zeroForOne, int256 amountSpecified, uint160, bytes calldata data)
        external
        returns (int256 amount0, int256 amount1)
    {
        SwapCallbackData memory _data = abi.decode(data, (SwapCallbackData));

        address tokenOut =
            (_data.tokenIn == arbitrumWrappedNativeTokenAddress ? globalGasToken : arbitrumWrappedNativeTokenAddress);

        console2.log("Gas Swap Data");
        console2.log("tokenIn", _data.tokenIn);
        console2.log("tokenOut", tokenOut);
        console2.log("isWrappedGasToken", _data.tokenIn != arbitrumWrappedNativeTokenAddress);

        if (tokenOut == arbitrumWrappedNativeTokenAddress) {
            deal(address(this), uint256(amountSpecified));
            WETH(arbitrumWrappedNativeTokenAddress).deposit{value: uint256(amountSpecified)}();
            MockERC20(arbitrumWrappedNativeTokenAddress).transfer(msg.sender, uint256(amountSpecified));
        } else {
            deal({token: tokenOut, to: msg.sender, give: uint256(amountSpecified)});
        }

        if (zeroForOne) {
            amount1 = amountSpecified;
        } else {
            amount0 = amountSpecified;
        }

        IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(amount0, amount1, data);
    }

    function slot0()
        external
        pure
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        )
    {
        return (100, 0, 0, 0, 0, 0, true);
    }
}
