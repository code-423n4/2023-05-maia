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

import {RootBridgeAgent, WETH9} from "./mocks/MockRootBridgeAgent.t.sol";
import {RootBridgeAgentExecutor} from "@omni/RootBridgeAgentExecutor.sol";
import {BranchBridgeAgent} from "./mocks/MockBranchBridgeAgent.t.sol";
import {ArbitrumBranchBridgeAgent} from "@omni/ArbitrumBranchBridgeAgent.sol";

import {BaseBranchRouter} from "@omni/BaseBranchRouter.sol";
import {MulticallRootRouter} from "@omni/MulticallRootRouter.sol";
import {CoreRootRouter} from "@omni/CoreRootRouter.sol";
import {ArbitrumCoreBranchRouter} from "@omni/ArbitrumCoreBranchRouter.sol";

import {ERC20hTokenRoot} from "@omni/token/ERC20hTokenRoot.sol";
import {ERC20hTokenRootFactory} from "@omni/factories/ERC20hTokenRootFactory.sol";
import {ERC20hTokenBranchFactory} from "@omni/factories/ERC20hTokenBranchFactory.sol";
import {RootBridgeAgentFactory} from "@omni/factories/RootBridgeAgentFactory.sol";
import {BranchBridgeAgentFactory} from "@omni/factories/BranchBridgeAgentFactory.sol";
import {ArbitrumBranchBridgeAgentFactory} from "@omni/factories/ArbitrumBranchBridgeAgentFactory.sol";

//UTILS
import {DepositParams, DepositMultipleParams} from "./mocks/MockRootBridgeAgent.t.sol";
import {Deposit, DepositStatus, DepositMultipleInput, DepositInput} from "@omni/interfaces/IBranchBridgeAgent.sol";

import {WETH9 as WETH} from "./mocks/WETH9.sol";
import {Multicall2} from "./mocks/Multicall2.sol";
contract MulticallRootRouterTest is DSTestPlus {
    uint32 nonce;

    MockERC20 avaxNativeAssethToken;

    MockERC20 avaxNativeToken;

    MockERC20 ftmNativeAssethToken;

    MockERC20 ftmNativeToken;

    MockERC20 rewardToken;

    ERC20hTokenRoot testToken;

    ERC20hTokenRootFactory hTokenFactory;

    RootPort rootPort;

    CoreRootRouter rootCoreRouter;

    MulticallRootRouter rootMulticallRouter;

    RootBridgeAgentFactory bridgeAgentFactory;

    RootBridgeAgent coreBridgeAgent;

    RootBridgeAgent multicallBridgeAgent;

    ArbitrumBranchPort localPortAddress;

    ArbitrumCoreBranchRouter arbitrumCoreRouter;

    BaseBranchRouter arbitrumMulticallRouter;

    ArbitrumBranchBridgeAgent arbitrumCoreBridgeAgent;

    ArbitrumBranchBridgeAgent arbitrumMulticallBridgeAgent;

    ERC20hTokenBranchFactory localHTokenFactory;

    ArbitrumBranchBridgeAgentFactory localBranchBridgeAgentFactory;

    uint24 rootChainId = uint24(42161);

    uint24 avaxChainId = uint24(1088);

    uint24 ftmChainId = uint24(2040);

    address avaxGlobalToken;

    address ftmGlobalToken;

    address wrappedNativeToken;

    address multicallAddress;

    address testGasPoolAddress = address(0xFFFF);

    address nonFungiblePositionManagerAddress = address(0xABAD);

    address avaxLocalWrappedNativeTokenAddress = address(0xBFFF);
    address avaxUnderlyingWrappedNativeTokenAddress = address(0xFFFB);

    address ftmLocalWrappedNativeTokenAddress = address(0xABBB);
    address ftmUnderlyingWrappedNativeTokenAddress = address(0xAAAB);

    address avaxCoreBridgeAgentAddress = address(0xBEEF);

    address avaxMulticallBridgeAgentAddress = address(0xEBFE);

    address avaxPortAddress = address(0xFEEB);

    address ftmCoreBridgeAgentAddress = address(0xCACA);

    address ftmMulticallBridgeAgentAddress = address(0xACAC);

    address ftmPortAddressM = address(0xABAC);

    address localAnyCallAddress = address(0xCAFE);

    address localAnyCongfig = address(new MockAnyConfig());

    address localAnyCallExecutorAddress = address(0xABFD);

    address owner = address(this);

    address dao = address(this);

    function setUp() public {
        //Mock calls
        hevm.mockCall(
            localAnyCallAddress, abi.encodeWithSignature("executor()"), abi.encode(localAnyCallExecutorAddress)
        );

        hevm.mockCall(localAnyCallAddress, abi.encodeWithSignature("config()"), abi.encode(localAnyCongfig));

        //Deploy Root Utils
        wrappedNativeToken = address(new WETH());

        multicallAddress = address(new Multicall2());

        //Deploy Root Contracts
        rootPort = new RootPort(rootChainId, wrappedNativeToken);

        bridgeAgentFactory = new RootBridgeAgentFactory(
            rootChainId,
            WETH9(wrappedNativeToken),
            localAnyCallAddress,
            address(rootPort),
            dao
        );

        rootCoreRouter = new CoreRootRouter(rootChainId, wrappedNativeToken, address(rootPort));

        rootMulticallRouter = new MulticallRootRouter(
            rootChainId,
            address(rootPort),
            multicallAddress
        );

        hTokenFactory = new ERC20hTokenRootFactory(rootChainId, address(rootPort));

        //Initialize Root Contracts
        rootPort.initialize(address(bridgeAgentFactory), address(rootCoreRouter));

        hevm.deal(address(rootPort), 1 ether);
        hevm.prank(address(rootPort));
        WETH(wrappedNativeToken).deposit{value: 1 ether}();

        hTokenFactory.initialize(address(rootCoreRouter));

        coreBridgeAgent = RootBridgeAgent(
            payable(RootBridgeAgentFactory(bridgeAgentFactory).createBridgeAgent(address(rootCoreRouter)))
        );

        multicallBridgeAgent = RootBridgeAgent(
            payable(RootBridgeAgentFactory(bridgeAgentFactory).createBridgeAgent(address(rootMulticallRouter)))
        );

        rootCoreRouter.initialize(address(coreBridgeAgent), address(hTokenFactory));

        rootMulticallRouter.initialize(address(multicallBridgeAgent));

        // Deploy Local Branch Contracts
        localPortAddress = new ArbitrumBranchPort(rootChainId, address(rootPort), owner);

        arbitrumMulticallRouter = new BaseBranchRouter();

        arbitrumCoreRouter = new ArbitrumCoreBranchRouter(address(0), address(localPortAddress));

        localBranchBridgeAgentFactory = new ArbitrumBranchBridgeAgentFactory(
            rootChainId,
            address(bridgeAgentFactory),
            WETH9(wrappedNativeToken),
            localAnyCallAddress,
            localAnyCallExecutorAddress,
            address(arbitrumCoreRouter),
            address(localPortAddress),
            owner
        );

        localPortAddress.initialize(address(arbitrumCoreRouter), address(localBranchBridgeAgentFactory));

        hevm.startPrank(address(arbitrumCoreRouter));

        arbitrumCoreBridgeAgent = ArbitrumBranchBridgeAgent(
            payable(
                localBranchBridgeAgentFactory.createBridgeAgent(
                    address(arbitrumCoreRouter), address(coreBridgeAgent), address(bridgeAgentFactory)
                )
            )
        );

        arbitrumMulticallBridgeAgent = ArbitrumBranchBridgeAgent(
            payable(
                localBranchBridgeAgentFactory.createBridgeAgent(
                    address(arbitrumMulticallRouter), address(rootMulticallRouter), address(bridgeAgentFactory)
                )
            )
        );

        hevm.stopPrank();

        arbitrumCoreRouter.initialize(address(arbitrumCoreBridgeAgent));
        arbitrumMulticallRouter.initialize(address(arbitrumMulticallBridgeAgent));

        // Deploy Remote Branchs Contracts

        //////////////////////////////////

        //Sync Root with new branches

        rootPort.initializeCore(address(coreBridgeAgent), address(arbitrumCoreBridgeAgent), address(localPortAddress));

        coreBridgeAgent.approveBranchBridgeAgent(avaxChainId);

        multicallBridgeAgent.approveBranchBridgeAgent(avaxChainId);

        coreBridgeAgent.approveBranchBridgeAgent(ftmChainId);

        multicallBridgeAgent.approveBranchBridgeAgent(ftmChainId);

        hevm.prank(address(rootCoreRouter));
        RootPort(rootPort).syncBranchBridgeAgentWithRoot(
            avaxCoreBridgeAgentAddress, address(coreBridgeAgent), avaxChainId
        );

        hevm.prank(address(rootCoreRouter));
        RootPort(rootPort).syncBranchBridgeAgentWithRoot(
            avaxMulticallBridgeAgentAddress, address(multicallBridgeAgent), avaxChainId
        );

        hevm.prank(address(rootCoreRouter));
        RootPort(rootPort).syncBranchBridgeAgentWithRoot(
            ftmCoreBridgeAgentAddress, address(coreBridgeAgent), ftmChainId
        );

        hevm.prank(address(rootCoreRouter));
        RootPort(rootPort).syncBranchBridgeAgentWithRoot(
            ftmMulticallBridgeAgentAddress, address(multicallBridgeAgent), ftmChainId
        );

        //Add new chains

        avaxGlobalToken = 0xa28317c06cb477885E7bAD12739B1d570D8bA157;

        ftmGlobalToken = 0x63762aF071E7e78B0DBAC62b41232884EbCA0968;

        hevm.mockCall(
            nonFungiblePositionManagerAddress,
            abi.encodeWithSignature(
                "createAndInitializePoolIfNecessary(address,address,uint24,uint160)",
                avaxGlobalToken,
                wrappedNativeToken,
                uint24(100),
                uint160(200)
            ),
            abi.encode(address(new MockPool(wrappedNativeToken,address(avaxGlobalToken))))
        );

        RootPort(rootPort).addNewChain(
            address(this),
            1 ether,
            avaxCoreBridgeAgentAddress,
            avaxChainId,
            "Avalanche",
            "AVAX",
            100,
            50,
            200,
            nonFungiblePositionManagerAddress,
            avaxLocalWrappedNativeTokenAddress,
            avaxUnderlyingWrappedNativeTokenAddress
        );

        //Mock calls
        hevm.mockCall(
            nonFungiblePositionManagerAddress,
            abi.encodeWithSignature(
                "createAndInitializePoolIfNecessary(address,address,uint24,uint160)",
                ftmGlobalToken,
                wrappedNativeToken,
                uint24(100),
                uint160(200)
            ),
            abi.encode(address(new MockPool(wrappedNativeToken, address(ftmGlobalToken))))
        );

        RootPort(rootPort).addNewChain(
            address(this),
            1 ether,
            ftmCoreBridgeAgentAddress,
            ftmChainId,
            "Fantom Opera",
            "FTM",
            100,
            50,
            200,
            nonFungiblePositionManagerAddress,
            ftmLocalWrappedNativeTokenAddress,
            ftmUnderlyingWrappedNativeTokenAddress
        );

        testToken = new ERC20hTokenRoot(
            rootChainId,
            address(bridgeAgentFactory),
            address(rootPort),
            "Hermes Global hToken 1",
            "hGT1"
        );

        //Ensure there are gas tokens from each chain in the system.
        hevm.startPrank(address(rootPort));
        ERC20hTokenRoot(avaxGlobalToken).mint(address(rootPort), 1 ether, avaxChainId);
        ERC20hTokenRoot(ftmGlobalToken).mint(address(rootPort), 1 ether, ftmChainId);
        hevm.stopPrank();

        require(
            RootPort(rootPort).getGlobalTokenFromLocal(address(avaxLocalWrappedNativeTokenAddress), avaxChainId)
                == avaxGlobalToken,
            "Token should be added"
        );

        require(
            RootPort(rootPort).getLocalTokenFromGlobal(avaxGlobalToken, avaxChainId)
                == address(avaxLocalWrappedNativeTokenAddress),
            "Token should be added"
        );
        require(
            RootPort(rootPort).getUnderlyingTokenFromLocal(address(avaxLocalWrappedNativeTokenAddress), avaxChainId)
                == address(avaxUnderlyingWrappedNativeTokenAddress),
            "Token should be added"
        );

        require(
            RootPort(rootPort).getGlobalTokenFromLocal(address(ftmLocalWrappedNativeTokenAddress), ftmChainId)
                == ftmGlobalToken,
            "Token should be added"
        );

        require(
            RootPort(rootPort).getLocalTokenFromGlobal(ftmGlobalToken, ftmChainId)
                == address(ftmLocalWrappedNativeTokenAddress),
            "Token should be added"
        );
        require(
            RootPort(rootPort).getUnderlyingTokenFromLocal(address(ftmLocalWrappedNativeTokenAddress), ftmChainId)
                == address(ftmUnderlyingWrappedNativeTokenAddress),
            "Token should be added"
        );

        avaxNativeAssethToken = new MockERC20("hTOKEN-AVAX", "LOCAL hTOKEN FOR TOKEN IN AVAX", 18);

        avaxNativeToken = new MockERC20("underlying token", "UNDER", 18);

        ftmNativeAssethToken = new MockERC20("hTOKEN-FTM", "LOCAL hTOKEN FOR TOKEN IN FMT", 18);

        ftmNativeToken = new MockERC20("underlying token", "UNDER", 18);

        rewardToken = new MockERC20("hermes token", "HERMES", 18);
    }

    address public newAvaxAssetGlobalAddress;

    function testAddLocalToken() public {
        //Encode Data
        bytes memory data =
            abi.encode(address(avaxNativeToken), address(avaxNativeAssethToken), "UnderLocal Coin", "UL");

        //Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x02), data);

        uint256 balanceBefore = MockERC20(wrappedNativeToken).balanceOf(address(coreBridgeAgent));

        //Call Deposit function
        encodeCallNoDeposit(
            payable(avaxCoreBridgeAgentAddress),
            payable(address(coreBridgeAgent)),
            uint32(1),
            packedData,
            0.00005 ether,
            0,
            avaxChainId
        );

        newAvaxAssetGlobalAddress =
            RootPort(rootPort).getGlobalTokenFromLocal(address(avaxNativeAssethToken), avaxChainId);

        console2.log("New: ", newAvaxAssetGlobalAddress);

        require(
            RootPort(rootPort).getGlobalTokenFromLocal(address(avaxNativeAssethToken), avaxChainId) != address(0),
            "Token should be added"
        );
        require(
            RootPort(rootPort).getLocalTokenFromGlobal(newAvaxAssetGlobalAddress, avaxChainId)
                == address(avaxNativeAssethToken),
            "Token should be added"
        );
        require(
            RootPort(rootPort).getUnderlyingTokenFromLocal(address(avaxNativeAssethToken), avaxChainId)
                == address(avaxNativeToken),
            "Token should be added"
        );

        console2.log("Balance Before: ", balanceBefore);
        console2.log("Balance After: ", address(coreBridgeAgent).balance);
    }

    address public newFtmAssetGlobalAddress;

    function testAddLocalTokenAlreadyAdded() internal {
        //Add once
        testAddLocalToken();

        //Encode Data
        bytes memory data =
            abi.encode(address(avaxNativeToken), address(avaxNativeAssethToken), "UnderLocal Coin", "UL");

        //Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x02), data);

        uint256 balanceBefore = MockERC20(wrappedNativeToken).balanceOf(address(coreBridgeAgent));

        //Expect revert
        hevm.expectRevert(abi.encodeWithSignature("TokenAlreadyAdded()"));

        //Call Deposit function
        encodeCallNoDeposit(
            payable(avaxCoreBridgeAgentAddress),
            payable(address(coreBridgeAgent)),
            uint32(1),
            packedData,
            0.00005 ether,
            0,
            avaxChainId
        );

        console2.log("Balance Before: ", balanceBefore);
        console2.log("Balance After: ", address(coreBridgeAgent).balance);
    }

    function testAddLocalTokenNotEnoughGas() internal {
        //Encode Data
        bytes memory data =
            abi.encode(address(avaxNativeToken), address(avaxNativeAssethToken), "UnderLocal Coin", "UL");

        //Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x02), data);

        //Expect revert
        hevm.expectRevert(abi.encodeWithSignature("InsufficientGasForFees()"));

        //Call Deposit function
        encodeCallNoDeposit(
            payable(avaxCoreBridgeAgentAddress),
            payable(address(coreBridgeAgent)),
            uint32(1),
            packedData,
            200,
            0,
            avaxChainId
        );
    }

    function testAddGlobalToken() public {
        //Add Local Token from Avax
        testAddLocalToken();

        //Encode Call Data
        bytes memory data = abi.encode(ftmCoreBridgeAgentAddress, newAvaxAssetGlobalAddress, ftmChainId, 0.000025 ether);

        //Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x01), data);

        //Call Deposit function
        encodeCallNoDeposit(
            payable(ftmCoreBridgeAgentAddress),
            payable(address(coreBridgeAgent)),
            uint32(1),
            packedData,
            0.0001 ether,
            0.00005 ether,
            ftmChainId
        );
        //State change occurs in setLocalToken
    }

    function testAddGlobalTokenAlreadyAdded() internal {
        //Add Local Token from Avax
        testSetLocalToken();

        //Encode Call Data
        bytes memory data = abi.encode(ftmCoreBridgeAgentAddress, newAvaxAssetGlobalAddress, ftmChainId, 0.000025 ether);

        //Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x01), data);

        hevm.expectRevert(abi.encodeWithSignature("TokenAlreadyAdded()"));

        //Call Deposit function
        encodeCallNoDeposit(
            payable(ftmCoreBridgeAgentAddress),
            payable(address(coreBridgeAgent)),
            uint32(1),
            packedData,
            0.0001 ether,
            0.00005 ether,
            ftmChainId
        );
    }

    function testAddGlobalTokenNotEnoughGas() internal {
        //Add Local Token from Avax
        testAddLocalToken();

        //Encode Call Data
        bytes memory data = abi.encode(ftmCoreBridgeAgentAddress, newAvaxAssetGlobalAddress, ftmChainId, 0.000025 ether);

        //Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x01), data);

        hevm.expectRevert(abi.encodeWithSignature("InsufficientGasForFees()"));

        //Call Deposit function
        encodeCallNoDeposit(
            payable(avaxCoreBridgeAgentAddress),
            payable(address(coreBridgeAgent)),
            uint32(1),
            packedData,
            0.0001 ether,
            0,
            avaxChainId
        );
    }

    address public newAvaxAssetLocalToken = address(0xFAFA);

    function testSetLocalToken() public {
        //Add Local Token from Avax
        testAddGlobalToken();

        //Encode Data
        bytes memory data = abi.encode(newAvaxAssetGlobalAddress, newAvaxAssetLocalToken, "UnderLocal Coin", "UL");

        //Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x03), data);

        //Call Deposit function
        encodeSystemCall(
            payable(ftmCoreBridgeAgentAddress),
            payable(address(coreBridgeAgent)),
            uint32(1),
            packedData,
            0.00001 ether,
            0,
            ftmChainId
        );

        require(
            RootPort(rootPort).getGlobalTokenFromLocal(newAvaxAssetLocalToken, ftmChainId) == newAvaxAssetGlobalAddress,
            "Token should be added"
        );
        require(
            RootPort(rootPort).getLocalTokenFromGlobal(newAvaxAssetGlobalAddress, ftmChainId) == newAvaxAssetLocalToken,
            "Token should be added"
        );
        require(
            RootPort(rootPort).getUnderlyingTokenFromLocal(address(newAvaxAssetLocalToken), ftmChainId) == address(0),
            "Token should not exist"
        );
    }

    address public mockApp = address(0xDAFA);

    //User Virtual Account
    address userVirtualAccount = 0xCB3b263f002b8888f712BA46EbF1302e1294608c;

    ////////////////////////////////////////////////////////////////////////// NO OUPUT ////////////////////////////////////////////////////////////////////

    function testMulticallNoOutputNoDeposit() public {
        hevm.mockCall(mockApp, abi.encodeWithSignature("distro()"), abi.encode(0));

        Multicall2.Call[] memory calls = new Multicall2.Call[](1);

        calls[0] =
            Multicall2.Call({target: mockApp, callData: abi.encodeWithSelector(bytes4(keccak256(bytes("distro()"))))});

        //RLP Encode Calldata
        bytes memory data = abi.encode(calls);

        //Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x01), data);

        uint32 currentNonce = nonce;

        //Call Deposit function
        encodeCallNoDeposit(
            payable(avaxMulticallBridgeAgentAddress),
            payable(multicallBridgeAgent),
            1,
            packedData,
            0.0001 ether,
            0,
            avaxChainId
        );

        require((multicallBridgeAgent).executionHistory(avaxChainId, currentNonce), "Nonce should be executed");
    }

    function testMulticallSignedNoOutputDepositSingle() public {
        //Add Local Token from Avax
        testSetLocalToken();

        Multicall2.Call[] memory calls = new Multicall2.Call[](1);

        //Prepare call to transfer 100 hAVAX form virtual account to Mock App (could be bribes)
        calls[0] = Multicall2.Call({
            target: newAvaxAssetGlobalAddress,
            callData: abi.encodeWithSelector(bytes4(0xa9059cbb), mockApp, 50 ether)
        });

        //RLP Encode Calldata
        bytes memory data = abi.encode(calls);

        //Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x01), data);

        //Call Deposit function
        encodeCallWithDeposit(
            payable(avaxMulticallBridgeAgentAddress),
            payable(multicallBridgeAgent),
            avaxChainId,
            _encodeSigned(
                1,
                address(this),
                address(avaxNativeAssethToken),
                address(avaxNativeToken),
                100 ether,
                100 ether,
                avaxChainId,
                packedData,
                0.0001 ether,
                0.00005 ether
            )
        );

        uint256 balanceTokenMockAppAfter = MockERC20(newAvaxAssetGlobalAddress).balanceOf(mockApp);
        uint256 balanceTokenPortAfter = MockERC20(newAvaxAssetGlobalAddress).balanceOf(address(rootPort));
        uint256 balanceTokenVirtualAccountAfter = MockERC20(newAvaxAssetGlobalAddress).balanceOf(userVirtualAccount);

        require(balanceTokenMockAppAfter == 50 ether, "Balance should be added");
        require(balanceTokenPortAfter == 0, "Balance should be cleared");
        require(balanceTokenVirtualAccountAfter == 50 ether, "Balance should be added");
    }

    function testMulticallSignedNoOutputDepositMultiple() public {
        //Add Local Token from Avax
        testSetLocalToken();

        //Prepare data
        address[] memory inputHTokenAddresses = new address[](2);
        address[] memory inputTokenAddresses = new address[](2);
        uint256[] memory inputTokenAmounts = new uint256[](2);
        uint256[] memory inputTokenDeposits = new uint256[](2);
        bytes memory packedData;

        {
            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            //Prepare call to transfer 100 wAVAX from virtual account to Mock App
            calls[0] = Multicall2.Call({
                target: newAvaxAssetGlobalAddress,
                callData: abi.encodeWithSelector(bytes4(0xa9059cbb), mockApp, 100 ether)
            });

            //RLP Encode Calldata
            bytes memory data = abi.encode(calls);

            //Pack FuncId
            packedData = abi.encodePacked(bytes1(0x01), data);

            //Prepare input token arrays
            inputHTokenAddresses[0] = address(newAvaxAssetLocalToken);
            inputTokenAddresses[0] = address(avaxUnderlyingWrappedNativeTokenAddress);
            inputTokenAmounts[0] = 100 ether;
            inputTokenDeposits[0] = 0;

            inputHTokenAddresses[1] = address(ftmLocalWrappedNativeTokenAddress);
            inputTokenAddresses[1] = address(ftmUnderlyingWrappedNativeTokenAddress);
            inputTokenAmounts[1] = 100 ether;
            inputTokenDeposits[1] = 100 ether;
        }

        //assure there are assets after mock action (mock previous branch port deposits)
        hevm.startPrank(address(rootPort));
        ERC20hTokenRoot(newAvaxAssetGlobalAddress).mint(address(rootPort), 100 ether, avaxChainId);
        hevm.stopPrank();

        uint256 balanceFtmPortBefore = MockERC20(ftmGlobalToken).balanceOf(address(rootPort));

        //Call Deposit function
        encodeCallWithDepositMultiple(
            payable(ftmMulticallBridgeAgentAddress),
            payable(multicallBridgeAgent),
            ftmChainId,
            _encodeMultipleSigned(
                1,
                address(this),
                inputHTokenAddresses,
                inputTokenAddresses,
                inputTokenAmounts,
                inputTokenDeposits,
                avaxChainId,
                packedData,
                0.0001 ether,
                0.00005 ether
            )
        );

        uint256 balanceTokenMockAppAfter = MockERC20(newAvaxAssetGlobalAddress).balanceOf(address(mockApp));
        uint256 balanceFtmMockAppAfter = MockERC20(ftmGlobalToken).balanceOf(address(mockApp));

        uint256 balanceTokenPortAfter = MockERC20(newAvaxAssetGlobalAddress).balanceOf(address(rootPort));
        uint256 balanceFtmPortAfter = MockERC20(ftmGlobalToken).balanceOf(address(rootPort));

        uint256 balanceTokenVirtualAccountAfter = MockERC20(newAvaxAssetGlobalAddress).balanceOf(userVirtualAccount);
        uint256 balanceFtmVirtualAccountAfter = MockERC20(ftmGlobalToken).balanceOf(userVirtualAccount);

        require(balanceTokenMockAppAfter == 100 ether, "Balance should be added");
        require(balanceFtmMockAppAfter == 0 ether, "Balance should stay equal");

        require(balanceTokenPortAfter == 0 ether, "Balance should stay equal");
        require(balanceFtmPortAfter == balanceFtmPortBefore, "Balance should stay equal");

        require(balanceTokenVirtualAccountAfter == 0 ether, "Balance should stay equal");
        require(balanceFtmVirtualAccountAfter == 100 ether, "Balance should be incremented");
    }

    ////////////////////////////////////////////////////////////////////////// SINGLE OUTPUT ////////////////////////////////////////////////////////////////////

    struct OutputParams {
        address recipient;
        address outputToken;
        uint256 amountOut;
        uint256 depositOut;
    }

    function testMulticallSingleOutputNoDeposit() public {
        //Add Local Token from Avax
        testSetLocalToken();

        //Prepare data
        address outputToken;
        uint256 amountOut;
        uint256 depositOut;
        bytes memory packedData;

        {
            outputToken = ftmGlobalToken;
            amountOut = 100 ether;
            depositOut = 50 ether;

            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            //Prepare call to transfer 100 hAVAX form virtual account to Mock App
            calls[0] = Multicall2.Call({target: 0x0000000000000000000000000000000000000000, callData: ""});

            //Output Params
            OutputParams memory outputParams = OutputParams(address(this), outputToken, amountOut, depositOut);

            //assure there are assets after mock action
            hevm.startPrank(address(rootPort));
            ERC20hTokenRoot(ftmGlobalToken).mint(userVirtualAccount, 100 ether, ftmChainId);
            hevm.stopPrank();

            //toChain
            uint24 toChain = ftmChainId;

            //RLP Encode Calldata
            bytes memory data = abi.encode(calls, outputParams, toChain);

            //Pack FuncId
            packedData = abi.encodePacked(bytes1(0x02), data);
        }

        uint256 balanceFtmPortBefore = MockERC20(ftmGlobalToken).balanceOf(address(rootPort));

        //Call Deposit function
        encodeCallNoDepositSigned(
            payable(avaxMulticallBridgeAgentAddress),
            payable(multicallBridgeAgent),
            1,
            address(this),
            packedData,
            0.0001 ether,
            0.00005 ether,
            avaxChainId
        );

        uint256 balanceFtmMockAppAfter = MockERC20(ftmGlobalToken).balanceOf(mockApp);

        uint256 balanceFtmPortAfter = MockERC20(ftmGlobalToken).balanceOf(address(rootPort));

        uint256 balanceFtmVirtualAccountAfter = MockERC20(ftmGlobalToken).balanceOf(userVirtualAccount);

        require(balanceFtmMockAppAfter == 0, "Balance should be cleared");

        require(balanceFtmPortAfter == balanceFtmPortBefore + 50 ether, "Balance should be cleared");

        require(balanceFtmVirtualAccountAfter == 0, "Balance should be cleared");
    }

    function testMulticallSignedSingleOutputNoDeposit() public {
        //Add Local Token from Avax
        testSetLocalToken();

        //Prepare data
        address outputToken;
        uint256 amountOut;
        uint256 depositOut;
        bytes memory packedData;

        {
            outputToken = ftmGlobalToken;
            amountOut = 50 ether;
            depositOut = 25 ether;

            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            //Prepare call to transfer 100 wFTM form virtual account to Mock App
            calls[0] = Multicall2.Call({
                target: ftmGlobalToken,
                callData: abi.encodeWithSelector(bytes4(0xa9059cbb), mockApp, 50 ether)
            });

            //assure there are assets for mock action
            hevm.startPrank(address(rootPort));
            ERC20hTokenRoot(ftmGlobalToken).mint(userVirtualAccount, 100 ether, ftmChainId);
            hevm.stopPrank();

            //Output Params
            OutputParams memory outputParams = OutputParams(address(this), outputToken, amountOut, depositOut);

            //toChain
            uint24 toChain = ftmChainId;

            //RLP Encode Calldata
            bytes memory data = abi.encode(calls, outputParams, toChain);

            //Pack FuncId
            packedData = abi.encodePacked(bytes1(0x02), data);
        }

        uint256 balanceFtmPortBefore = MockERC20(ftmGlobalToken).balanceOf(address(rootPort));

        //Call Deposit function
        encodeCallNoDepositSigned(
            payable(avaxMulticallBridgeAgentAddress),
            payable(multicallBridgeAgent),
            1,
            address(this),
            packedData,
            0.0001 ether,
            0.00005 ether,
            avaxChainId
        );

        uint256 balanceFtmMockAppAfter = MockERC20(ftmGlobalToken).balanceOf(mockApp);

        uint256 balanceFtmPortAfter = MockERC20(ftmGlobalToken).balanceOf(address(rootPort));

        uint256 balanceFtmVirtualAccountAfter = MockERC20(ftmGlobalToken).balanceOf(userVirtualAccount);

        require(balanceFtmMockAppAfter == 50 ether, "Balance should be increased");

        require(balanceFtmPortAfter == balanceFtmPortBefore + 25 ether, "Balance should be half");

        require(balanceFtmVirtualAccountAfter == 0, "Balance should stay 0");
    }

    function testMulticallSignedSingleOutputDepositSingle() public {
        //Add Local Token from Avax
        testSetLocalToken();

        require(
            RootPort(rootPort).getLocalTokenFromGlobal(newAvaxAssetGlobalAddress, ftmChainId) == newAvaxAssetLocalToken,
            "Token should be added"
        );

        //Prepare data
        address outputToken;
        uint256 amountOut;
        uint256 depositOut;
        bytes memory packedData;

        {
            outputToken = newAvaxAssetGlobalAddress;
            amountOut = 100 ether;
            depositOut = 50 ether;

            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            //Prepare call to transfer 100 hAVAX form virtual account to Mock App 
            calls[0] = Multicall2.Call({target: 0x0000000000000000000000000000000000000000, callData: ""});

            //Output Params
            OutputParams memory outputParams = OutputParams(address(this), outputToken, amountOut, depositOut);

            // assure there are assets after mock action
            hevm.startPrank(address(rootPort));
            ERC20hTokenRoot(newAvaxAssetGlobalAddress).mint(address(rootPort), 100 ether, avaxChainId);
            hevm.stopPrank();

            //toChain
            uint24 toChain = avaxChainId;

            //RLP Encode Calldata
            bytes memory data = abi.encode(calls, outputParams, toChain);

            //Pack FuncId
            packedData = abi.encodePacked(bytes1(0x02), data);
        }

        //Call Deposit function
        encodeCallWithDeposit(
            payable(ftmMulticallBridgeAgentAddress),
            payable(multicallBridgeAgent),
            ftmChainId,
            _encodeSigned(
                1,
                address(this),
                address(newAvaxAssetLocalToken),
                address(0),
                100 ether,
                0,
                ftmChainId,
                packedData,
                0.0001 ether,
                0.00005 ether
            )
        );

        uint256 balanceTokenMockAppAfter = MockERC20(newAvaxAssetGlobalAddress).balanceOf(mockApp);

        uint256 balanceTokenPortAfter = MockERC20(newAvaxAssetGlobalAddress).balanceOf(address(rootPort));

        uint256 balanceTokenVirtualAccountAfter = MockERC20(newAvaxAssetGlobalAddress).balanceOf(userVirtualAccount);

        require(balanceTokenMockAppAfter == 0, "Balance should be cleared");

        require(balanceTokenPortAfter == 50 ether, "Balance should be cleared");

        require(balanceTokenVirtualAccountAfter == 0, "Balance should be cleared");
    }

    function testMulticallSignedSingleOutputDepositMultiple() public {
        //Add Local Token from Avax
        testSetLocalToken();

        //Prepare data
        address outputToken;
        uint256 amountOut;
        uint256 depositOut;

        address[] memory inputHTokenAddresses = new address[](2);
        address[] memory inputTokenAddresses = new address[](2);
        uint256[] memory inputTokenAmounts = new uint256[](2);
        uint256[] memory inputTokenDeposits = new uint256[](2);
        bytes memory packedData;

        {
            outputToken = ftmGlobalToken;
            amountOut = 100 ether;
            depositOut = 50 ether;

            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            //Prepare call to transfer 100 hAVAX form virtual account to Mock App
            calls[0] = Multicall2.Call({
                target: newAvaxAssetGlobalAddress,
                callData: abi.encodeWithSelector(bytes4(0xa9059cbb), mockApp, 100 ether)
            });

            //Output Params
            OutputParams memory outputParams = OutputParams(address(this), outputToken, amountOut, depositOut);

            //RLP Encode Calldata
            bytes memory data = abi.encode(calls, outputParams, ftmChainId);

            //Pack FuncId
            packedData = abi.encodePacked(bytes1(0x02), data);

            //Prepare input token arrays

            inputHTokenAddresses[0] = address(newAvaxAssetLocalToken);
            inputTokenAddresses[0] = address(avaxUnderlyingWrappedNativeTokenAddress);
            inputTokenAmounts[0] = 100 ether;
            inputTokenDeposits[0] = 0;

            inputHTokenAddresses[1] = address(ftmLocalWrappedNativeTokenAddress);
            inputTokenAddresses[1] = address(ftmUnderlyingWrappedNativeTokenAddress);
            inputTokenAmounts[1] = 100 ether;
            inputTokenDeposits[1] = 100 ether;
        }

        //assure there are assets after mock action
        hevm.startPrank(address(rootPort));
        ERC20hTokenRoot(newAvaxAssetGlobalAddress).mint(address(rootPort), 100 ether, avaxChainId);
        hevm.stopPrank();

        uint256 balanceFtmPortBefore = MockERC20(ftmGlobalToken).balanceOf(address(rootPort));

        //Call Deposit function
        encodeCallWithDepositMultiple(
            payable(ftmMulticallBridgeAgentAddress),
            payable(multicallBridgeAgent),
            ftmChainId,
            _encodeMultipleSigned(
                1,
                address(this),
                inputHTokenAddresses,
                inputTokenAddresses,
                inputTokenAmounts,
                inputTokenDeposits,
                avaxChainId,
                packedData,
                0.0001 ether,
                0.00005 ether
            )
        );

        uint256 balanceTokenMockAppAfter = MockERC20(newAvaxAssetGlobalAddress).balanceOf(mockApp);
        uint256 balanceFtmMockAppAfter = MockERC20(ftmGlobalToken).balanceOf(mockApp);

        uint256 balanceTokenPortAfter = MockERC20(newAvaxAssetGlobalAddress).balanceOf(address(rootPort));
        uint256 balanceFtmPortAfter = MockERC20(ftmGlobalToken).balanceOf(address(rootPort));

        uint256 balanceTokenVirtualAccountAfter = MockERC20(newAvaxAssetGlobalAddress).balanceOf(userVirtualAccount);
        uint256 balanceFtmVirtualAccountAfter = MockERC20(ftmGlobalToken).balanceOf(userVirtualAccount);

        require(balanceTokenMockAppAfter == 100 ether, "Balance should be added");
        require(balanceFtmMockAppAfter == 0, "Balance should be cleared");

        require(balanceTokenPortAfter == 0, "Balance should be cleared");
        require(balanceFtmPortAfter == balanceFtmPortBefore + 50 ether, "Balance should be added");

        require(balanceTokenVirtualAccountAfter == 0, "Balance should be cleared");
        require(balanceFtmVirtualAccountAfter == 0, "Balance should be cleared");
    }

    ////////////////////////////////////////////////////////////////////////// MULTIPLE OUTPUT ////////////////////////////////////////////////////////////////////

    struct OutputMultipleParams {
        address recipient;
        address[] outputTokens;
        uint256[] amountsOut;
        uint256[] depositsOut;
    }

    function testMulticallMultipleOutputNoDeposit() public {
        //Add Local Token from Avax
        testSetLocalToken();

        require(
            RootPort(rootPort).getLocalTokenFromGlobal(newAvaxAssetGlobalAddress, ftmChainId) == newAvaxAssetLocalToken,
            "Token should be added"
        );

        //Prepare data
        address[] memory outputTokens = new address[](2);
        uint256[] memory amountsOut = new uint256[](2);
        uint256[] memory depositsOut = new uint256[](2);
        bytes memory packedData;

        {
            outputTokens[0] = ftmGlobalToken;
            outputTokens[1] = newAvaxAssetGlobalAddress;
            amountsOut[0] = 100 ether;
            amountsOut[1] = 100 ether;
            depositsOut[0] = 50 ether;
            depositsOut[1] = 0 ether;

            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            //Prepare call to transfer 100 hAVAX form virtual account to Mock App (could be bribes)
            calls[0] = Multicall2.Call({target: 0x0000000000000000000000000000000000000000, callData: ""});

            //Output Params
            OutputMultipleParams memory outputMultipleParams =
                OutputMultipleParams(address(this), outputTokens, amountsOut, depositsOut);

            //assure there are assets after mock action
            hevm.startPrank(address(rootPort));
            ERC20hTokenRoot(ftmGlobalToken).mint(address(rootMulticallRouter), 100 ether, ftmChainId);
            ERC20hTokenRoot(newAvaxAssetGlobalAddress).mint(address(rootMulticallRouter), 100 ether, avaxChainId);
            hevm.stopPrank();

            //toChain
            uint24 toChain = ftmChainId;

            //RLP Encode Calldata
            bytes memory data = abi.encode(calls, outputMultipleParams, toChain);

            //Pack FuncId
            packedData = abi.encodePacked(bytes1(0x03), data);
        }

        //Call Deposit function
        encodeCallNoDeposit(
            payable(avaxMulticallBridgeAgentAddress),
            payable(multicallBridgeAgent),
            1,
            packedData,
            0.0001 ether,
            0.00005 ether,
            avaxChainId
        );

        uint256 balanceAfter = MockERC20(newAvaxAssetGlobalAddress).balanceOf(address(rootMulticallRouter));
        uint256 balanceFtmAfter = MockERC20(ftmGlobalToken).balanceOf(address(rootMulticallRouter));

        require(balanceAfter == 0, "Balance should be cleared");
        require(balanceFtmAfter == 0, "Balance should be cleared");

        uint256 balanceTokenMockAppAfter = MockERC20(newAvaxAssetGlobalAddress).balanceOf(mockApp);

        require(balanceTokenMockAppAfter == 0, "Balance should be cleared");
        require(balanceTokenMockAppAfter == 0, "Balance should be cleared");
    }

    function testMulticallSignedMultipleOutputNoDeposit() public {
        //Add Local Token from Avax
        testSetLocalToken();

        require(
            RootPort(rootPort).getLocalTokenFromGlobal(newAvaxAssetGlobalAddress, ftmChainId) == newAvaxAssetLocalToken,
            "Token should be added"
        );

        //Prepare data
        address[] memory outputTokens = new address[](2);
        uint256[] memory amountsOut = new uint256[](2);
        uint256[] memory depositsOut = new uint256[](2);
        bytes memory packedData;

        {
            outputTokens[0] = ftmGlobalToken;
            amountsOut[0] = 50 ether;
            depositsOut[0] = 50 ether;

            outputTokens[1] = newAvaxAssetGlobalAddress;
            amountsOut[1] = 100 ether;
            depositsOut[1] = 0 ether;

            //assure there are assets after mock action
            hevm.startPrank(address(rootPort));
            ERC20hTokenRoot(ftmGlobalToken).mint(address(userVirtualAccount), 100 ether, ftmChainId);
            ERC20hTokenRoot(newAvaxAssetGlobalAddress).mint(address(userVirtualAccount), 100 ether, avaxChainId);
            hevm.stopPrank();

            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            //Prepare call to transfer 50 wFTM global token from virtual account to Mock App (could be bribes)
            calls[0] = Multicall2.Call({
                target: ftmGlobalToken,
                callData: abi.encodeWithSelector(bytes4(0xa9059cbb), mockApp, 50 ether)
            });

            //Output Params
            OutputMultipleParams memory outputMultipleParams =
                OutputMultipleParams(address(this), outputTokens, amountsOut, depositsOut);

            //toChain
            uint24 toChain = ftmChainId;

            //RLP Encode Calldata
            bytes memory data = abi.encode(calls, outputMultipleParams, toChain);

            //Pack FuncId
            packedData = abi.encodePacked(bytes1(0x03), data);
        }

        //Call Deposit function
        encodeCallNoDepositSigned(
            payable(avaxMulticallBridgeAgentAddress),
            payable(multicallBridgeAgent),
            1,
            address(this),
            packedData,
            0.0001 ether,
            0.00005 ether,
            avaxChainId
        );

        uint256 balanceTokenAfter = MockERC20(newAvaxAssetGlobalAddress).balanceOf(userVirtualAccount);
        uint256 balanceTokenPortAfter = MockERC20(newAvaxAssetGlobalAddress).balanceOf(address(rootPort));

        uint256 balanceFtmAfter = MockERC20(ftmGlobalToken).balanceOf(userVirtualAccount);
        uint256 balanceFtmPortAfter = MockERC20(ftmGlobalToken).balanceOf(address(rootPort));

        uint256 mockAppBalanceAfter = MockERC20(ftmGlobalToken).balanceOf(mockApp);

        console2.log("Balances After:");
        console2.log("Global Token Virtual Account Balance After:", balanceTokenAfter);
        console2.log("Global Token Port Balance After:", balanceTokenPortAfter);

        console2.log("Global Token Virtual Account Balance After:", balanceFtmPortAfter);
        console2.log("Global FTM Port Balance After:", balanceFtmAfter);

        console2.log("Mock App Balance After:", mockAppBalanceAfter);

        require(balanceTokenAfter == 0, "Virtual account should be empty");
        require(balanceTokenPortAfter == 100 ether, "Balance be in Port");
    }

    function testMulticallSignedMultipleOutputDepositSingle() public {
        //Add Local Token from Avax
        testSetLocalToken();

        //Prepare data
        address[] memory outputTokens = new address[](2);
        uint256[] memory amountsOut = new uint256[](2);
        uint256[] memory depositsOut = new uint256[](2);
        bytes memory packedData;

        {
            outputTokens[0] = ftmGlobalToken;
            amountsOut[0] = 50 ether;
            depositsOut[0] = 25 ether;

            outputTokens[1] = newAvaxAssetGlobalAddress;
            amountsOut[1] = 100 ether;
            depositsOut[1] = 0 ether;

            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            //Prepare call to transfer 100 hAVAX form virtual account to Mock App (could be bribes)
            calls[0] = Multicall2.Call({
                target: ftmGlobalToken,
                callData: abi.encodeWithSelector(bytes4(0xa9059cbb), mockApp, 100 ether)
            });

            //Get some tokens into Virtual Account to be created with this call
            hevm.startPrank(address(rootPort));
            ERC20hTokenRoot(ftmGlobalToken).mint(userVirtualAccount, 150 ether, ftmChainId);
            hevm.stopPrank();

            //Output Params
            OutputMultipleParams memory outputMultipleParams =
                OutputMultipleParams(address(this), outputTokens, amountsOut, depositsOut);

            //toChain
            uint24 toChain = ftmChainId;

            //RLP Encode Calldata
            bytes memory data = abi.encode(calls, outputMultipleParams, toChain);

            //Pack FuncId
            packedData = abi.encodePacked(bytes1(0x03), data);
        }

        console2.log("Initiating Cross-Chain call");
        console2.log("Messaging Layer Data Length:", packedData.length);

        uint256 balanceGlobalFtmBefore = MockERC20(ftmGlobalToken).balanceOf(address(rootPort));

        //Call Deposit function
        encodeCallWithDeposit(
            payable(avaxMulticallBridgeAgentAddress),
            payable(multicallBridgeAgent),
            avaxChainId,
            _encodeSigned(
                1,
                address(this),
                address(avaxNativeAssethToken),
                address(avaxNativeToken),
                100 ether,
                100 ether,
                ftmChainId,
                packedData,
                0.0001 ether,
                0.00005 ether
            )
        );

        uint256 balanceGlobalTokenAfter = MockERC20(newAvaxAssetGlobalAddress).balanceOf(address(rootPort));
        uint256 balanceGlobalFtmAfter = MockERC20(ftmGlobalToken).balanceOf(address(rootPort));
        uint256 mockAppBalanceAfter = MockERC20(ftmGlobalToken).balanceOf(mockApp);

        console2.log("Balances After:");
        console2.log("Global Token Port Balance After:", balanceGlobalTokenAfter);
        console2.log("Global FTM Port Balance After:", balanceGlobalFtmAfter);
        console2.log("Mock App Balance After:", mockAppBalanceAfter);

        require(
            balanceGlobalTokenAfter == 100 ether,
            "Port should not have accumulated tokens since no hTokens were cleared"
        );

        require(
            balanceGlobalFtmAfter == balanceGlobalFtmBefore + 25 ether,
            "Port should have cleared half the 50 new hTokens for branch redemption"
        );

        require(mockAppBalanceAfter == 100 ether, "dApp interaction failed");
    }

    function testMulticallSignedMultipleOutputDepositMultiple() public {
        //Add Local Token from Avax
        testSetLocalToken();

        require(
            RootPort(rootPort).getLocalTokenFromGlobal(newAvaxAssetGlobalAddress, ftmChainId) == newAvaxAssetLocalToken,
            "Token should be added"
        );

        //Prepare data
        address[] memory outputTokens = new address[](2);
        uint256[] memory amountsOut = new uint256[](2);
        uint256[] memory depositsOut = new uint256[](2);

        address[] memory inputHTokenAddresses = new address[](2);
        address[] memory inputTokenAddresses = new address[](2);
        uint256[] memory inputTokenAmounts = new uint256[](2);
        uint256[] memory inputTokenDeposits = new uint256[](2);

        bytes memory packedData;

        {
            outputTokens[0] = ftmGlobalToken;
            outputTokens[1] = newAvaxAssetGlobalAddress;
            amountsOut[0] = 100 ether;
            amountsOut[1] = 100 ether;
            depositsOut[0] = 50 ether;
            depositsOut[1] = 0 ether;

            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            //Prepare call to transfer 100 hAVAX form virtual account to Mock App (could be bribes)
            calls[0] = Multicall2.Call({target: 0x0000000000000000000000000000000000000000, callData: ""});

            //Output Params
            OutputMultipleParams memory outputMultipleParams =
                OutputMultipleParams(address(this), outputTokens, amountsOut, depositsOut);

            //toChain
            uint24 toChain = ftmChainId;

            //RLP Encode Calldata
            bytes memory data = abi.encode(calls, outputMultipleParams, toChain);

            //Pack FuncId
            packedData = abi.encodePacked(bytes1(0x03), data);

            //Prepare input token arrays
            inputHTokenAddresses[0] = address(newAvaxAssetLocalToken);
            inputHTokenAddresses[1] = address(ftmLocalWrappedNativeTokenAddress);

            inputTokenAddresses[0] = address(avaxUnderlyingWrappedNativeTokenAddress);
            inputTokenAddresses[1] = address(ftmUnderlyingWrappedNativeTokenAddress);

            inputTokenAmounts[0] = 100 ether;
            inputTokenAmounts[1] = 100 ether;

            inputTokenDeposits[0] = 0;
            inputTokenDeposits[1] = 100 ether;
        }

        //assure there are assets after mock action
        hevm.startPrank(address(rootPort));
        ERC20hTokenRoot(newAvaxAssetGlobalAddress).mint(address(rootPort), 100 ether, avaxChainId);
        hevm.stopPrank();

        //Call Deposit function
        encodeCallWithDepositMultiple(
            payable(ftmMulticallBridgeAgentAddress),
            payable(multicallBridgeAgent),
            ftmChainId,
            _encodeMultipleSigned(
                1,
                address(this),
                inputHTokenAddresses,
                inputTokenAddresses,
                inputTokenAmounts,
                inputTokenDeposits,
                avaxChainId,
                packedData,
                0.0001 ether,
                0.00005 ether
            )
        );

        uint256 balanceAfter =
            MockERC20(newAvaxAssetGlobalAddress).balanceOf(address(0x4f81992FCe2E1846dD528eC0102e6eE1f61ed3e2));
        uint256 balanceFtmAfter =
            MockERC20(ftmGlobalToken).balanceOf(address(0x4f81992FCe2E1846dD528eC0102e6eE1f61ed3e2));

        require(balanceAfter == 0, "Balance should be cleared");
        require(balanceFtmAfter == 0, "Balance should be cleared");

        uint256 balanceTokenMockAppAfter = MockERC20(newAvaxAssetGlobalAddress).balanceOf(mockApp);

        require(balanceTokenMockAppAfter == 0, "Balance should be cleared");
        require(balanceTokenMockAppAfter == 0, "Balance should be cleared");
    }

    //////////////////////////////////////////////////////////////////////////   HELPERS   ////////////////////////////////////////////////////////////////////

    function encodeSystemCall(
        address payable _fromBridgeAgent,
        address payable _toBridgeAgent,
        uint32,
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
        bytes memory inputCalldata = abi.encodePacked(bytes1(0x00), nonce++, _data, _rootExecGas, _remoteExecGas);

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
        uint32,
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
        bytes memory inputCalldata = abi.encodePacked(bytes1(0x01), nonce++, _data, _rootExecGas, _remoteExecGas);

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
        uint32,
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
        bytes memory inputCalldata = abi.encodePacked(bytes1(0x04), _user, nonce++, _data, _rootExecGas, _remoteExecGas);

        hevm.mockCall(
            address(localAnyCongfig),
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
            address(localAnyCongfig),
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
            address(localAnyCongfig),
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

    function _encodeSystemCall(uint32, bytes memory _data, uint128 _rootExecGas, uint128 _remoteExecGas)
        internal
        returns (bytes memory inputCalldata)
    {
        //Encode Data
        inputCalldata = abi.encodePacked(bytes1(0x00), nonce++, _data, _rootExecGas, _remoteExecGas);
    }

    function _encodeNoDeposit(uint32, bytes memory _data, uint128 _rootExecGas, uint128 _remoteExecGas)
        internal
        returns (bytes memory inputCalldata)
    {
        //Encode Data
        inputCalldata = abi.encodePacked(bytes1(0x01), nonce++, _data, _rootExecGas, _remoteExecGas);
    }

    function _encodeNoDepositSigned(
        uint32,
        address _user,
        bytes memory _data,
        uint128 _rootExecGas,
        uint128 _remoteExecGas
    ) internal returns (bytes memory inputCalldata) {
        //Encode Data
        inputCalldata = abi.encodePacked(bytes1(0x04), _user, nonce++, _data, _rootExecGas, _remoteExecGas);
    }

    function _encode(
        uint32,
        address _hToken,
        address _token,
        uint256 _amount,
        uint256 _deposit,
        uint24 _toChain,
        bytes memory _data,
        uint128 _rootExecGas,
        uint128 _remoteExecGas
    ) internal returns (bytes memory inputCalldata) {
        //Encode Data
        inputCalldata = abi.encodePacked(
            bytes1(0x02), nonce++, _hToken, _token, _amount, _deposit, _toChain, _data, _rootExecGas, _remoteExecGas
        );
    }

    function _encodeSigned(
        uint32,
        address _user,
        address _hToken,
        address _token,
        uint256 _amount,
        uint256 _deposit,
        uint24 _toChain,
        bytes memory _data,
        uint128 _rootExecGas,
        uint128 _remoteExecGas
    ) internal returns (bytes memory inputCalldata) {
        //Encode Data
        inputCalldata = abi.encodePacked(
            bytes1(0x05),
            _user,
            nonce++,
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
        uint32,
        address[] memory _hTokens,
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256[] memory _deposits,
        uint24 _toChain,
        bytes memory _data,
        uint128 _rootExecGas,
        uint128 _remoteExecGas
    ) internal returns (bytes memory inputCalldata) {
        //Encode Data
        inputCalldata = abi.encodePacked(
            bytes1(0x03),
            uint8(_hTokens.length),
            nonce++,
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
        uint32,
        address _user,
        address[] memory _hTokens,
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256[] memory _deposits,
        uint24 _toChain,
        bytes memory _data,
        uint128 _rootExecGas,
        uint128 _remoteExecGas
    ) internal returns (bytes memory inputCalldata) {
        //Encode Data
        inputCalldata = abi.encodePacked(
            bytes1(0x06),
            _user,
            uint8(_hTokens.length),
            nonce++,
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

contract MockAnyConfig {
    function deposit(address account) external payable {}
}

interface IUniswapV3SwapCallback {
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata _data) external;
}

contract MockPool is Test {
    struct SwapCallbackData {
        address tokenIn;
    }

    address wrappedNativeTokenAddress;
    address globalGasToken;

    constructor(address _wrappedNativeTokenAddress, address _globalGasToken) {
        wrappedNativeTokenAddress = _wrappedNativeTokenAddress;
        globalGasToken = _globalGasToken;
    }

    function swap(address, bool zeroForOne, int256 amountSpecified, uint160, bytes calldata data)
        external
        returns (int256 amount0, int256 amount1)
    {
        SwapCallbackData memory _data = abi.decode(data, (SwapCallbackData));

        address tokenOut = (_data.tokenIn == wrappedNativeTokenAddress ? globalGasToken : wrappedNativeTokenAddress);

        console2.log("GAS SWAP");
        console2.log("tokenIn:", _data.tokenIn);
        console2.log("tokenOut:", tokenOut);
        console2.log("isWrappedGasToken:");
        console2.log(_data.tokenIn != wrappedNativeTokenAddress);

        if (tokenOut == wrappedNativeTokenAddress) {
            deal(address(this), uint256(amountSpecified));
            WETH(wrappedNativeTokenAddress).deposit{value: uint256(amountSpecified)}();
            MockERC20(wrappedNativeTokenAddress).transfer(msg.sender, uint256(amountSpecified));
        } else {
            deal({token: tokenOut, to: msg.sender, give: uint256(amountSpecified)});
        }
        console2.log(MockERC20(tokenOut).balanceOf(msg.sender));
        console2.log(amountSpecified);

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
