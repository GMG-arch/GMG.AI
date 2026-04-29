// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DepositUsdt is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public tokenUSDT;

    address[] public financeAddrs;

    uint256 public nonce; //防重

    event FinanceAdded(address indexed addr);
    event FinanceRemoved(address indexed addr);
    event Deposit(
        address indexed user,
        uint256 amount,
        address indexed finance
    );

    constructor(address _usdt) {
        require(_usdt != address(0), "invalid USDT");
        tokenUSDT = IERC20(_usdt);
    }

    function setFinanceAddresses(address[] calldata _list) external onlyOwner {
        require(_list.length > 0, "empty");
        financeAddrs = _list;
    }

    function _randomFinance() internal returns (address) {
        require(financeAddrs.length > 0, "no finance");
        nonce++;
        uint256 rand = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    msg.sender,
                    nonce,
                    block.prevrandao
                )
            )
        );

        return financeAddrs[rand % financeAddrs.length];
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "amount = 0");

        tokenUSDT.safeTransferFrom(msg.sender, address(this), amount);

        address finance = _randomFinance();

        tokenUSDT.safeTransfer(finance, amount);

        emit Deposit(msg.sender, amount, finance);
    }

    function getFinance() external view returns (address[] memory) {
        return financeAddrs;
    }
}
