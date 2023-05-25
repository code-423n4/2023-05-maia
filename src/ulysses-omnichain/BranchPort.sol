// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {IPortStrategy} from "./interfaces/IPortStrategy.sol";
import {IBranchPort} from "./interfaces/IBranchPort.sol";

import {ERC20hTokenBranch} from "./token/ERC20hTokenBranch.sol";

/// @title Branch Port - Omnichain Token Management Contract
contract BranchPort is Ownable, IBranchPort {
    using SafeTransferLib for address;

    /// @notice Local Core Branch Router Address.
    address public coreBranchRouterAddress;

    /*///////////////////////////////////////////////////////////////
                        BRIDGE AGENT STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping from Underlying Address to isUnderlying (bool).
    mapping(address => bool) public isBridgeAgent;

    /// @notice Branch Routers deployed in branc chain.
    address[] public bridgeAgents;

    /// @notice Number of Branch Routers deployed in current chain.
    uint256 public bridgeAgentsLenght;

    /*///////////////////////////////////////////////////////////////
                    BRIDGE AGENT FACTORIES STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping from Underlying Address to isUnderlying (bool).
    mapping(address => bool) public isBridgeAgentFactory;

    /// @notice Branch Routers deployed in branc chain.
    address[] public bridgeAgentFactories;

    /// @notice Number of Branch Routers deployed in current chain.
    uint256 public bridgeAgentFactoriesLenght;

    /*///////////////////////////////////////////////////////////////
                        PORT STRATEGY STATE
    //////////////////////////////////////////////////////////////*/
    /// Strategy Tokens

    /// @notice Mapping returns true if Strategy Token Address is active for usage in Port Strategies.
    mapping(address => bool) public isStrategyToken;

    /// @notice List of Tokens whitelisted for usage in Port Strategies.
    address[] public strategyTokens;

    /// @notice Number of Port Strategies deployed in current branch chain.
    uint256 public strategyTokensLenght;

    /// @notice Mapping returns a given token's total debt incurred by Port Strategies.
    mapping(address => uint256) public getStrategyTokenDebt;

    /// @notice Mapping returns the minimum ratio of a given Strategy Token the Port should hold.
    mapping(address => uint256) public getMinimumTokenReserveRatio;

    /// Port Strategies

    /// @notice Mapping returns true if Port Startegy is allowed to manage a given Strategy Token. Strategy => Token => bool.
    mapping(address => mapping(address => bool)) public isPortStrategy;

    /// @notice Port Strategy Addresses deployed in current branch chain.
    address[] public portStrategies;

    /// @notice Number of Port Strategies deployed in current branch chain.
    uint256 public portStrategiesLenght;

    /// @notice Mapping returns the amount of Strategy Token debt a given Port Startegy has.  Strategy => Token => uint256.
    mapping(address => mapping(address => uint256)) public getPortStrategyTokenDebt;

    /// @notice Mapping returns the last time a given Port Strategy managed a given Strategy Token. Strategy => Token => uint256.
    mapping(address => mapping(address => uint256)) public lastManaged;

    /// @notice Mapping returns the time limit a given Port Strategy must wait before managing a Strategy Token. Strategy => Token => uint256.
    mapping(address => mapping(address => uint256)) public strategyDailyLimitAmount;

    /// @notice Mapping returns the amount of a Strategy Token a given Port Strategy can manage.
    mapping(address => mapping(address => uint256)) public strategyDailyLimitRemaining;

    uint256 internal constant DIVISIONER = 1e4;
    uint256 internal constant MIN_RESERVE_RATIO = 3e3;

    constructor(address _owner) {
        require(_owner != address(0), "Owner is zero address");
        _initializeOwner(_owner);
    }

    function initialize(address _coreBranchRouter, address _bridgeAgentFactory) external virtual onlyOwner {
        require(coreBranchRouterAddress == address(0), "Contract already initialized");
        require(!isBridgeAgentFactory[_bridgeAgentFactory], "Contract already initialized");

        require(_coreBranchRouter != address(0), "CoreBranchRouter is zero address");
        require(_bridgeAgentFactory != address(0), "BridgeAgentFactory is zero address");

        coreBranchRouterAddress = _coreBranchRouter;
        isBridgeAgentFactory[_bridgeAgentFactory] = true;
        bridgeAgentFactories.push(_bridgeAgentFactory);
        bridgeAgentFactoriesLenght++;
    }

    /// @notice Function being overrriden to prevent mistakenly renouncing ownership.
    function renounceOwnership() public payable override onlyOwner {
        revert("Cannot renounce ownership");
    }

    /*///////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns amount of Strategy Tokens
     *   @param _token Address of a given Strategy Token.
     *   @return uint256 excess reserves
     */
    function _excessReserves(address _token) internal view returns (uint256) {
        uint256 currBalance = ERC20(_token).balanceOf(address(this));
        uint256 minReserves = _minimumReserves(currBalance, _token);
        return currBalance > minReserves ? currBalance - minReserves : 0;
    }

    /**
     * @notice Returns amount of Strategy Tokens needed to reach minimum reserves
     *   @param _token Address of a given Strategy Token.
     *   @return uint256 excess reserves
     */
    function _reservesLacking(address _token) internal view returns (uint256) {
        uint256 currBalance = ERC20(_token).balanceOf(address(this));
        uint256 minReserves = _minimumReserves(currBalance, _token);
        return currBalance < minReserves ? minReserves - currBalance : 0;
    }

    /**
     * @notice Internal function to return the minimum amount of reserves of a given Strategy Token the Port should hold.
     *   @param _currBalance Current balance of a given Strategy Token.
     *   @param _token Address of a given Strategy Token.
     *   @return uint256 minimum reserves
     */
    function _minimumReserves(uint256 _currBalance, address _token) internal view returns (uint256) {
        return ((_currBalance + getStrategyTokenDebt[_token]) * getMinimumTokenReserveRatio[_token]) / DIVISIONER;
    }

    /*///////////////////////////////////////////////////////////////
                        PORT STRATEGY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBranchPort
    function manage(address _token, uint256 _amount) external requiresPortStrategy(_token) {
        if (_amount > _excessReserves(_token)) revert InsufficientReserves();

        _checkTimeLimit(_token, _amount);

        getStrategyTokenDebt[_token] += _amount;
        getPortStrategyTokenDebt[msg.sender][_token] += _amount;

        _token.safeTransfer(msg.sender, _amount);

        emit DebtCreated(msg.sender, _token, _amount);
    }

    /// @inheritdoc IBranchPort
    function replenishReserves(address _strategy, address _token, uint256 _amount) external lock {
        if (!isStrategyToken[_token]) revert UnrecognizedStrategyToken();
        if (!isPortStrategy[_strategy][_token]) revert UnrecognizedPortStrategy();

        uint256 reservesLacking = _reservesLacking(_token);

        uint256 amountToWithdraw = _amount < reservesLacking ? _amount : reservesLacking;

        IPortStrategy(_strategy).withdraw(address(this), _token, amountToWithdraw);

        getPortStrategyTokenDebt[_strategy][_token] -= amountToWithdraw;
        getStrategyTokenDebt[_token] -= amountToWithdraw;

        emit DebtRepaid(_strategy, _token, amountToWithdraw);
    }

    /**
     * @notice Internal function to check if a Port Strategy has reached its daily management limit.
     *   @param _token address being managed.
     *   @param _amount of token being requested.
     */
    function _checkTimeLimit(address _token, uint256 _amount) internal {
        if (block.timestamp - lastManaged[msg.sender][_token] >= 1 days) {
            strategyDailyLimitRemaining[msg.sender][_token] = strategyDailyLimitAmount[msg.sender][_token];
        }
        strategyDailyLimitRemaining[msg.sender][_token] -= _amount;
        lastManaged[msg.sender][_token] = block.timestamp;
    }

    /*///////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBranchPort
    function withdraw(address _recipient, address _underlyingAddress, uint256 _deposit)
        external
        virtual
        requiresBridgeAgent
    {
        _underlyingAddress.safeTransfer(
            _recipient, _denormalizeDecimals(_deposit, ERC20(_underlyingAddress).decimals())
        );
    }

    /// @inheritdoc IBranchPort
    function bridgeIn(address _recipient, address _localAddress, uint256 _amount)
        external
        virtual
        requiresBridgeAgent
    {
        ERC20hTokenBranch(_localAddress).mint(_recipient, _amount);
    }

    /// @inheritdoc IBranchPort
    function bridgeInMultiple(address _recipient, address[] memory _localAddresses, uint256[] memory _amounts)
        external
        virtual
        requiresBridgeAgent
    {
        for (uint256 i = 0; i < _localAddresses.length;) {
            ERC20hTokenBranch(_localAddresses[i]).mint(_recipient, _amounts[i]);

            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc IBranchPort
    function bridgeOut(
        address _depositor,
        address _localAddress,
        address _underlyingAddress,
        uint256 _amount,
        uint256 _deposit
    ) external virtual requiresBridgeAgent {
        if (_amount - _deposit > 0) {
            _localAddress.safeTransferFrom(_depositor, address(this), _amount - _deposit);
            ERC20hTokenBranch(_localAddress).burn(_amount - _deposit);
        }
        if (_deposit > 0) {
            _underlyingAddress.safeTransferFrom(
                _depositor, address(this), _denormalizeDecimals(_deposit, ERC20(_underlyingAddress).decimals())
            );
        }
    }

    /// @inheritdoc IBranchPort
    function bridgeOutMultiple(
        address _depositor,
        address[] memory _localAddresses,
        address[] memory _underlyingAddresses,
        uint256[] memory _amounts,
        uint256[] memory _deposits
    ) external virtual requiresBridgeAgent {
        for (uint256 i = 0; i < _localAddresses.length;) {
            if (_deposits[i] > 0) {
                _underlyingAddresses[i].safeTransferFrom(
                    _depositor,
                    address(this),
                    _denormalizeDecimals(_deposits[i], ERC20(_underlyingAddresses[i]).decimals())
                );
            }
            if (_amounts[i] - _deposits[i] > 0) {
                _localAddresses[i].safeTransferFrom(_depositor, address(this), _amounts[i] - _deposits[i]);
                ERC20hTokenBranch(_localAddresses[i]).burn(_amounts[i] - _deposits[i]);
            }
            unchecked {
                i++;
            }
        }
    }

    /*///////////////////////////////////////////////////////////////
                    BRIDGE AGENT FACTORIES FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBranchPort
    function addBridgeAgent(address _bridgeAgent) external requiresBridgeAgentFactory {
        isBridgeAgent[_bridgeAgent] = true;
        bridgeAgents.push(_bridgeAgent);
        bridgeAgentsLenght++;
    }

    /*///////////////////////////////////////////////////////////////
                        ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBranchPort
    function setCoreRouter(address _newCoreRouter) external requiresCoreRouter {
        require(coreBranchRouterAddress != address(0), "CoreRouter address is zero");
        require(_newCoreRouter != address(0), "New CoreRouter address is zero");
        coreBranchRouterAddress = _newCoreRouter;
    }

    /// @inheritdoc IBranchPort
    function addBridgeAgentFactory(address _newBridgeAgentFactory) external requiresCoreRouter {
        isBridgeAgentFactory[_newBridgeAgentFactory] = true;
        bridgeAgentFactories.push(_newBridgeAgentFactory);
        bridgeAgentFactoriesLenght++;

        emit BridgeAgentFactoryAdded(_newBridgeAgentFactory);
    }

    /// @inheritdoc IBranchPort
    function toggleBridgeAgentFactory(address _newBridgeAgentFactory) external requiresCoreRouter {
        isBridgeAgentFactory[_newBridgeAgentFactory] = !isBridgeAgentFactory[_newBridgeAgentFactory];

        emit BridgeAgentFactoryToggled(_newBridgeAgentFactory);
    }

    /// @inheritdoc IBranchPort
    function toggleBridgeAgent(address _bridgeAgent) external requiresCoreRouter {
        isBridgeAgent[_bridgeAgent] = !isBridgeAgent[_bridgeAgent];

        emit BridgeAgentToggled(_bridgeAgent);
    }

    /// @inheritdoc IBranchPort
    function addStrategyToken(address _token, uint256 _minimumReservesRatio) external requiresCoreRouter {
        if (_minimumReservesRatio >= DIVISIONER) revert InvalidMinimumReservesRatio();
        strategyTokens.push(_token);
        strategyTokensLenght++;
        getMinimumTokenReserveRatio[_token] = _minimumReservesRatio;
        isStrategyToken[_token] = true;

        emit StrategyTokenAdded(_token, _minimumReservesRatio);
    }

    /// @inheritdoc IBranchPort
    function toggleStrategyToken(address _token) external requiresCoreRouter {
        isStrategyToken[_token] = !isStrategyToken[_token];

        emit StrategyTokenToggled(_token);
    }

    /// @inheritdoc IBranchPort
    function addPortStrategy(address _portStrategy, address _token, uint256 _dailyManagementLimit)
        external
        requiresCoreRouter
    {
        if (!isStrategyToken[_token]) revert UnrecognizedStrategyToken();
        portStrategies.push(_portStrategy);
        portStrategiesLenght++;
        strategyDailyLimitAmount[_portStrategy][_token] = _dailyManagementLimit;
        isPortStrategy[_portStrategy][_token] = true;

        emit PortStrategyAdded(_portStrategy, _token, _dailyManagementLimit);
    }

    /// @inheritdoc IBranchPort
    function togglePortStrategy(address _portStrategy, address _token) external requiresCoreRouter {
        isPortStrategy[_portStrategy][_token] = !isPortStrategy[_portStrategy][_token];

        emit PortStrategyToggled(_portStrategy, _token);
    }

    /// @inheritdoc IBranchPort
    function updatePortStrategy(address _portStrategy, address _token, uint256 _dailyManagementLimit)
        external
        requiresCoreRouter
    {
        strategyDailyLimitAmount[_portStrategy][_token] = _dailyManagementLimit;

        emit PortStrategyUpdated(_portStrategy, _token, _dailyManagementLimit);
    }

    /*///////////////////////////////////////////////////////////////
                            HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function that denormalizes an input from 18 decimal places.
     * @param _amount amount of tokens
     * @param _decimals number of decimal places
     */
    function _denormalizeDecimals(uint256 _amount, uint8 _decimals) internal pure returns (uint256) {
        return _decimals == 18 ? _amount : _amount * 1 ether / (10 ** _decimals);
    }

    /*///////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Modifier that verifies msg sender is the Branch Chain's Core Root Router.
    modifier requiresCoreRouter() {
        if (msg.sender != coreBranchRouterAddress) revert UnrecognizedCore();
        _;
    }

    /// @notice Modifier that verifies msg sender is an active Bridge Agent.
    modifier requiresBridgeAgent() {
        if (!isBridgeAgent[msg.sender]) revert UnrecognizedBridgeAgent();
        _;
    }

    /// @notice Modifier that verifies msg sender is an active Bridge Agent Factory.
    modifier requiresBridgeAgentFactory() {
        if (!isBridgeAgentFactory[msg.sender]) revert UnrecognizedBridgeAgentFactory();
        _;
    }

    /// @notice Modifier that require msg sender to be an active Port Strategy
    modifier requiresPortStrategy(address _token) {
        if (!isPortStrategy[msg.sender][_token]) revert UnrecognizedPortStrategy();
        _;
    }

    uint256 internal _unlocked = 1;

    /// @notice Modifier for a simple re-entrancy check.
    modifier lock() {
        require(_unlocked == 1);
        _unlocked = 2;
        _;
        _unlocked = 1;
    }
}
