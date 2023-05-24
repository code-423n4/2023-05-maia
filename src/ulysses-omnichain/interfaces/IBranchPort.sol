// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @title  Branch Port - Omnichain Token Management Contract
 * @author MaiaDAO
 * @notice Ulyses `Port` implementation for Branch Chain deployment. This contract
 *         is used to manage the deposit and withdrawal of underlying assets from
 *         the Branch Chain in response to Branch Bridge Agents' requests.
 *         Manages Bridge Agents and their factories as well as the chain's strategies and
 *         their tokens.
 */
interface IBranchPort {
    /*///////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Returns true if the address is a Bridge Agent.
     *   @param _bridgeAgent Bridge Agent address.
     *   @return bool.
     */
    function isBridgeAgent(address _bridgeAgent) external view returns (bool);

    /**
     * @notice Returns true if the address is a Strategy Token.
     *   @param _token token address.
     *   @return bool.
     */
    function isStrategyToken(address _token) external view returns (bool);

    /**
     * @notice Returns true if the address is a Port Strategy.
     *   @param _strategy strategy address.
     *   @param _token token address.
     *   @return bool.
     */
    function isPortStrategy(address _strategy, address _token) external view returns (bool);

    /**
     * @notice Returns true if the address is a Bridge Agent Factory.
     *   @param _bridgeAgentFactory Bridge Agent Factory address.
     *   @return bool.
     */
    function isBridgeAgentFactory(address _bridgeAgentFactory) external view returns (bool);

    /*///////////////////////////////////////////////////////////////
                          PORT STRATEGY MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Allows active Port Strategy addresses to withdraw assets.
     *     @param _token token address.
     *     @param _amount amount of tokens.
     */
    function manage(address _token, uint256 _amount) external;

    /**
     * @notice allow approved address to repay borrowed reserves with reserves
     *     @param _amount uint
     *     @param _token address
     */
    function replenishReserves(address _strategy, address _token, uint256 _amount) external;

    /*///////////////////////////////////////////////////////////////
                          hTOKEN MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Function to withdraw underlying / native token amount into Port in exchange for Local hToken.
     *   @param _recipient hToken receiver.
     *   @param _underlyingAddress underlying / native token address.
     *   @param _amount amount of tokens.
     *
     */
    function withdraw(address _recipient, address _underlyingAddress, uint256 _amount) external;

    /**
     * @notice Setter function to increase local hToken supply.
     *   @param _recipient hToken receiver.
     *   @param _localAddress token address.
     *   @param _amount amount of tokens.
     *
     */
    function bridgeIn(address _recipient, address _localAddress, uint256 _amount) external;

    /**
     * @notice Setter function to increase local hToken supply.
     *   @param _recipient hToken receiver.
     *   @param _localAddresses token addresses.
     *   @param _amounts amount of tokens.
     *
     */
    function bridgeInMultiple(address _recipient, address[] memory _localAddresses, uint256[] memory _amounts)
        external;

    /**
     * @notice Setter function to decrease local hToken supply.
     *   @param _localAddress token address.
     *   @param _amount amount of tokens.
     *
     */
    function bridgeOut(
        address _depositor,
        address _localAddress,
        address _underlyingAddress,
        uint256 _amount,
        uint256 _deposit
    ) external;

    /**
     * @notice Setter function to decrease local hToken supply.
     *   @param _depositor user to deduct balance from.
     *   @param _localAddresses local token addresses.
     *   @param _underlyingAddresses local token address.
     *   @param _amounts amount of local tokens.
     *   @param _deposits amount of underlying tokens.
     *
     */
    function bridgeOutMultiple(
        address _depositor,
        address[] memory _localAddresses,
        address[] memory _underlyingAddresses,
        uint256[] memory _amounts,
        uint256[] memory _deposits
    ) external;

    /*///////////////////////////////////////////////////////////////
                        ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new bridge agent address to the branch port.
     *   @param _bridgeAgent address of the bridge agent to add to the Port
     */
    function addBridgeAgent(address _bridgeAgent) external;

    /**
     * @notice Sets the core router address for the branch port.
     *   @param _newCoreRouter address of the new core router
     */
    function setCoreRouter(address _newCoreRouter) external;

    /**
     * @notice Adds a new bridge agent factory address to the branch port.
     *   @param _bridgeAgentFactory address of the bridge agent factory to add to the Port
     */
    function addBridgeAgentFactory(address _bridgeAgentFactory) external;

    /**
     * @notice Reverts the toggle on the given bridge agent factory. If it's active, it will de-activate it and vice-versa.
     *   @param _newBridgeAgentFactory address of the bridge agent factory to add to the Port
     */
    function toggleBridgeAgentFactory(address _newBridgeAgentFactory) external;

    /**
     * @notice Reverts thfe toggle on the given bridge agent  If it's active, it will de-activate it and vice-versa.
     *   @param _bridgeAgent address of the bridge agent to add to the Port
     */
    function toggleBridgeAgent(address _bridgeAgent) external;

    /**
     * @notice Adds a new strategy token.
     * @param _token address of the token to add to the Strategy Tokens
     */
    function addStrategyToken(address _token, uint256 _minimumReservesRatio) external;

    /**
     * @notice Reverts the toggle on the given strategy token. If it's active, it will de-activate it and vice-versa.
     * @param _token address of the token to add to the Strategy Tokens
     */
    function toggleStrategyToken(address _token) external;

    /**
     * @notice Adds a new Port strategy to the given port
     * @param _portStrategy address of the bridge agent factory to add to the Port
     */
    function addPortStrategy(address _portStrategy, address _token, uint256 _dailyManagementLimit) external;

    /**
     * @notice Reverts the toggle on the given port strategy. If it's active, it will de-activate it and vice-versa.
     * @param _portStrategy address of the bridge agent factory to add to the Port
     */
    function togglePortStrategy(address _portStrategy, address _token) external;

    /**
     * @notice Updates the daily management limit for the given port strategy.
     * @param _portStrategy address of the bridge agent factory to add to the Port
     * @param _token address of the token to update the limit for
     * @param _dailyManagementLimit new daily management limit
     */
    function updatePortStrategy(address _portStrategy, address _token, uint256 _dailyManagementLimit) external;

    /*///////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event DebtCreated(address indexed _strategy, address indexed _token, uint256 _amount);
    event DebtRepaid(address indexed _strategy, address indexed _token, uint256 _amount);

    event StrategyTokenAdded(address indexed _token, uint256 _minimumReservesRatio);
    event StrategyTokenToggled(address indexed _token);

    event PortStrategyAdded(address indexed _portStrategy, address indexed _token, uint256 _dailyManagementLimit);
    event PortStrategyToggled(address indexed _portStrategy, address indexed _token);
    event PortStrategyUpdated(address indexed _portStrategy, address indexed _token, uint256 _dailyManagementLimit);

    event BridgeAgentFactoryAdded(address indexed _bridgeAgentFactory);
    event BridgeAgentFactoryToggled(address indexed _bridgeAgentFactory);

    event BridgeAgentToggled(address indexed _bridgeAgent);

    /*///////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidMinimumReservesRatio();
    error InsufficientReserves();
    error UnrecognizedCore();
    error UnrecognizedBridgeAgent();
    error UnrecognizedBridgeAgentFactory();
    error UnrecognizedPortStrategy();
    error UnrecognizedStrategyToken();
}
