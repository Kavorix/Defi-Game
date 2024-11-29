// SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title IEgg
/// @dev Interface for the Egg ERC20 token contract.
interface IEgg is IERC20 {
    /// @notice Mints tokens and assigns them to the specified address.
    /// @param _to The address to which the tokens will be minted.
    /// @param _amount The amount of tokens to mint.
    function mint(address _to, uint256 _amount) external;

    /// @notice Sets the address of the ants contract.
    /// @param _ants The address of the ants contract.
    function setAnts(address _ants) external;
}

/// @title Egg
/// @dev The contract for the Egg ERC20 token, which is Ownable.
contract Egg is ERC20, IEgg, Ownable {
    address public ants;

    /// @dev Constructor for the Egg contract, initializes the ERC20 token with the name 'EGG' and symbol 'EGG'.
    constructor() ERC20('EGG', 'EGG') Ownable(_msgSender()) {}

    /// @inheritdoc IEgg
    function mint(address _to, uint256 _amount) external override {
        //solhint-disable-next-line
        require(_msgSender() == ants, "Only the ants contract can call this function, please refer to the ants contract");
        _mint(_to, _amount);
    }

    /// @inheritdoc IEgg
    function setAnts(address _ants) external onlyOwner {
        ants = _ants;
    }
}
