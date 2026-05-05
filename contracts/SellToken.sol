// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IUniswapV2Router02 {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function getAmountsOut(
        uint amountIn,
        address[] calldata path
    ) external view returns (uint[] memory amounts);
}

contract SellTokenSwap {
    using SafeERC20 for IERC20;

    address public owner;
    IERC20 public token;
    IERC20 public usdt;
    IUniswapV2Router02 public router;

    address[] public treasuries;
    uint256 public nextTreasuryIndex;

    event Sell(
        address indexed user,
        uint256 tokenAmount,
        uint256 usdtAmount,
        address treasury,
        string bizId
    );
    event TreasuriesUpdated(address[] treasuries);

    constructor(address _token, address _usdt, address _router) {
        owner = msg.sender;
        token = IERC20(_token);
        usdt = IERC20(_usdt);
        router = IUniswapV2Router02(_router);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
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

    function sell(uint256 amount, string calldata bizId) external {
        require(amount > 0, "amount=0");
        require(treasuries.length > 0, "no treasury");

        token.safeTransferFrom(msg.sender, address(this), amount);

        token.safeApprove(address(router), 0);
        token.safeApprove(address(router), amount);

        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = address(usdt);

        uint256 beforeBalance = usdt.balanceOf(address(this));
        uint256[] memory expected = router.getAmountsOut(amount, path);
        uint256 minOut = (expected[1] * 95) / 100;

        router.swapExactTokensForTokens(
            amount,
            minOut,
            path,
            address(this),
            block.timestamp
        );

        uint256 afterBalance = usdt.balanceOf(address(this));
        uint256 received = afterBalance - beforeBalance;

        require(received > 0, "no usdt");

        address treasury = treasuries[nextTreasuryIndex];
        nextTreasuryIndex = (nextTreasuryIndex + 1) % treasuries.length;

        usdt.safeTransfer(treasury, received);

        emit Sell(msg.sender, amount, received, treasury, bizId);
    }
}
