// SPDX-License-Identifier: Unlicense

pragma solidity >=0.8.4 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "forge-std/console.sol";

/// @title IEgg
/// @dev Interface for the Egg ERC20 token contract.
interface IEgg is IERC20 {
    /// @notice Mints tokens and assigns them to the specified address.
    /// @param _to The address to which the tokens will be minted.
    /// @param _amount The amount of tokens to mint.
    function mint(address _to, uint256 _amount) external;
}

/// @title ICryptoAnts
/// @dev Interface for the CryptoAnts ERC721 contract.
interface ICryptoAnts is IERC721 {
    /// @notice Emitted when eggs are bought.
    event EggsBought(address indexed buyer, uint256 amount);

    /// @notice Emitted when an ant is sold.
    event AntSold(uint256 indexed AntId, address indexed seller);

    /// @notice Emitted when an ant is created.
    event AntCreated(uint256 indexed AntId, address indexed creator);

    /// @dev Custom error message for Already exist Ant id.
    error AlreadyExists();

    /// @dev Custom error message for wrong ether sent.
    error WrongEtherSent();

    /// @dev Custom error message for No eggs balance.
    error NoEggs();

    /// @dev Custom error message for Invalid Eggs Price.
    error EggsPriceNotSet();

    /// @dev Custom error message for Wrong amount of Eggs minting .
    error WrongAmount();

    /// @dev Custom error message for unauthorized access.
    error NotAuthorized();

    /// @dev Custom error message for external call failed.
    error CallFailed();

    /// @notice Buys eggs with Ether.
    /// @param _amount The amount of eggs to buy.
    function buyEggs(uint256 _amount) external payable;

    /// @notice Sets the price of eggs.
    /// @param _price The new price of eggs.
    function SetEggsPrice(uint256 _price) external;

    /// @notice Creates a new ant.
    function createAnt() external;

    /// @notice Sells an ant.
    /// @param _antId The ID of the ant to sell.
    function sellAnt(uint256 _antId) external;

    /// @notice Retrieves the contract balance.
    /// @return The balance of the contract.
    function getContractBalance() external view returns (uint256);

    /// @notice Retrieves the total number of ants created.
    /// @return The total number of ants created.
    function getAntsCreated() external view returns (uint256);
}

/// @title CryptoAnts
/// @dev The contract for the CryptoAnts ERC721 token, which is Ownable and ReentrancyGuard.
contract CryptoAnts is ERC721, ICryptoAnts, ReentrancyGuard, Ownable {
    bool public locked = false;
    mapping(uint256 => address) public antToOwner;

    IEgg public immutable eggs;
    uint256 public eggPrice = 0.001 ether;

    uint256[] public allAntsIds;

    uint256 public antsCreated = 0;

    address public governance;

    /// @dev Modifier to only allow access by the governor.
    modifier onlyGovernor() {
        if (_msgSender() != governance) revert NotAuthorized();
        _;
    }

    /// @dev Constructor for the CryptoAnts contract.
    constructor(
        address _eggs
    ) ERC721("Crypto Ants", "ANTS") Ownable(_msgSender()) {
        eggs = IEgg(_eggs);
    }

    /// @inheritdoc ICryptoAnts
    /// @param _amount The amount of eggs the user intends to buy.
    /// @dev Allows users to buy eggs by sending Ether to the contract.
    function buyEggs(uint256 _amount) external payable override nonReentrant {
        if (eggPrice <= 0) revert EggsPriceNotSet();

        uint256 eggsCallerCanBuy = msg.value / eggPrice;

        // Ensure the caller can buy at least one egg
        if (eggsCallerCanBuy <= 0) revert WrongEtherSent();
        if (_amount > eggsCallerCanBuy * 1e18) revert WrongAmount();

        // Mint the appropriate number of eggs based on the Ether sent
        eggs.mint(_msgSender(), eggsCallerCanBuy);

        // Emit event indicating eggs were bought
        emit EggsBought(_msgSender(), eggsCallerCanBuy);
    }

    /// @inheritdoc ICryptoAnts
    function SetEggsPrice(uint256 _price) external override onlyGovernor {
        eggPrice = _price;
    }

    /// @inheritdoc ICryptoAnts
    /// @dev Allows users to create a new ant, provided they have at least 1 egg.
    function createAnt() external override nonReentrant {
        if (eggs.balanceOf(_msgSender()) < 1) revert NoEggs();
        uint256 _antId = ++antsCreated;
        for (uint256 i = 0; i < allAntsIds.length; i++) {
            if (allAntsIds[i] == _antId) revert AlreadyExists();
        }
        _mint(_msgSender(), _antId);
        antToOwner[_antId] = _msgSender();
        allAntsIds.push(_antId);
        emit AntCreated(_antId, _msgSender());
    }

    /// @inheritdoc ICryptoAnts
    function sellAnt(uint256 _antId) external override nonReentrant {
        if (antToOwner[_antId] != _msgSender()) revert NotAuthorized();
        // solhint-disable-next-line
        (bool success, ) = _msgSender().call{value: 0.0004 ether}("");
        if (!success) revert CallFailed();
        delete antToOwner[_antId];
        _burn(_antId);
        emit AntSold(_antId, _msgSender());
    }

    /// @inheritdoc ICryptoAnts
    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    /// @inheritdoc ICryptoAnts
    function getAntsCreated() public view returns (uint256) {
        return antsCreated;
    }

    /// @notice Sets the governance address.
    /// @param _governance The address of the governance.
    function setGovernance(address _governance) public onlyOwner {
        governance = _governance;
    }
}
