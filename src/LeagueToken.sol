// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title LeagueToken
 * @notice $LEAGUE ERC20 token for IVirtualz platform
 * @dev Used for betting, LP provision, and governance
 */
contract LeagueToken is ERC20, Ownable {
    uint256 public constant MAX_SUPPLY = 100_000_000 * 10**18; // 100M tokens

    constructor(address _initialOwner) ERC20("IVirtualz League Token", "LEAGUE") Ownable(_initialOwner) {
        // Mint initial supply to owner for distribution
        _mint(_initialOwner, MAX_SUPPLY);
    }

    /**
     * @notice Burn tokens
     * @param amount Amount to burn
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
