// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title LeagueBetToken
 * @notice The native protocol token for LeagueBet
 * @dev All bets are placed in LBT, creating buy pressure and value accrual
 */
contract LeagueBetToken is ERC20, Ownable {
    /// @notice Maximum supply cap (100 million tokens)
    uint256 public constant MAX_SUPPLY = 100_000_000 ether;

    /// @notice Tracks total minted supply
    uint256 public totalMinted;

    event TokensMinted(address indexed to, uint256 amount);
    event TokensBurned(address indexed from, uint256 amount);

    /**
     * @notice Constructor mints initial supply to deployer
     * @param initialSupply Initial token supply (in wei)
     */
    constructor(uint256 initialSupply) ERC20("LeagueBet Token", "LBT") Ownable(msg.sender) {
        require(initialSupply <= MAX_SUPPLY, "Exceeds max supply");
        _mint(msg.sender, initialSupply);
        totalMinted = initialSupply;
    }

    /**
     * @notice Mint new tokens (for rewards, incentives)
     * @param to Recipient address
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        require(totalMinted + amount <= MAX_SUPPLY, "Exceeds max supply");
        _mint(to, amount);
        totalMinted += amount;
        emit TokensMinted(to, amount);
    }

    /**
     * @notice Burn tokens from caller's balance
     * @param amount Amount to burn
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
        emit TokensBurned(msg.sender, amount);
    }

    /**
     * @notice Burn tokens from specified address (with approval)
     * @param from Address to burn from
     * @param amount Amount to burn
     */
    function burnFrom(address from, uint256 amount) external {
        _spendAllowance(from, msg.sender, amount);
        _burn(from, amount);
        emit TokensBurned(from, amount);
    }
}
