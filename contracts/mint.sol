// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MintToken is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public usdt;
    address[] public treasuries;
    uint256 public nextTreasuryIndex;

    event Mint(
        address indexed user,
        uint256 usdtAmount,
        address indexed treasury,
        uint256 timestamp
    );
    event TreasuriesUpdated(address[] treasuries);

    constructor(address _usdt) {
        require(_usdt != address(0), "invalid address");

        usdt = IERC20(_usdt);
    }

    function setTreasuries(address[] calldata _treasuries) external onlyOwner {
        require(_treasuries.length > 0, "empty treasuries");
        delete treasuries;
        for (uint256 i = 0; i < _treasuries.length; i++) {
            require(_treasuries[i] != address(0), "zero address");
            treasuries.push(_treasuries[i]);
        }
        nextTreasuryIndex = 0;
        emit TreasuriesUpdated(treasuries);
    }

    function getTreasuries() external view returns (address[] memory) {
        return treasuries;
    }

    function mint(uint256 amount) external {
        require(amount >= 100 * 1e18, "Minimum mintage 100");
        require(treasuries.length > 0, "no treasury");

        usdt.safeTransferFrom(msg.sender, address(this), amount);
        address treasury = treasuries[nextTreasuryIndex];
        nextTreasuryIndex = (nextTreasuryIndex + 1) % treasuries.length;
        usdt.safeTransfer(treasury, amount);
        emit Mint(msg.sender, amount, treasury, block.timestamp);
    }

    function rescueToken(
        address _token,
        address to,
        uint256 amount
    ) external onlyOwner {
        require(to != address(0), "zero address");

        IERC20 t = IERC20(_token);
        uint256 bal = t.balanceOf(address(this));
        uint256 out = amount == 0 ? bal : amount;

        require(bal >= out, "insufficient");

        t.safeTransfer(to, out);
    }
}
