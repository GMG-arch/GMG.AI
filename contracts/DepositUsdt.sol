// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DepositUsdt is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public tokenUSDT;

    address[] public treasuries;
    uint256 public nextTreasuryIndex;
    event TreasuriesUpdated(address[] treasuries);
    event Deposit(
        address indexed user,
        uint256 amount,
        address indexed treasury
    );

    constructor(address _usdt) {
        require(_usdt != address(0), "invalid USDT");
        tokenUSDT = IERC20(_usdt);
    }

    function setTreasuries(address[] calldata _list) external onlyOwner {
        require(_list.length > 0, "empty");
        delete treasuries;
        for (uint256 i = 0; i < _list.length; i++) {
            require(_list[i] != address(0), "zero address");
            treasuries.push(_list[i]);
        }
        nextTreasuryIndex = 0;
        emit TreasuriesUpdated(treasuries);
    }

    function getTreasuries() external view returns (address[] memory) {
        return treasuries;
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "amount = 0");
        require(treasuries.length > 0, "no treasury");

        tokenUSDT.safeTransferFrom(msg.sender, address(this), amount);

        address treasury = treasuries[nextTreasuryIndex];
        nextTreasuryIndex = (nextTreasuryIndex + 1) % treasuries.length;

        tokenUSDT.safeTransfer(treasury, amount);

        emit Deposit(msg.sender, amount, treasury);
    }
}
