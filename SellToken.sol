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

    address[] public financeAddresses;

    event Sell(
        address indexed user,
        uint256 tokenAmount,
        uint256 usdtAmount,
        address finance,
        string bizId
    );

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

    function setFinanceAddresses(address[] calldata _list) external onlyOwner {
        require(_list.length > 0, "empty");
        financeAddresses = _list;
    }

    function sell(uint256 amount, string calldata bizId) external {
        require(amount > 0, "amount=0");
        require(financeAddresses.length > 0, "no finance");

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

        uint256 rand = uint256(
            keccak256(
                abi.encodePacked(block.timestamp, block.prevrandao, msg.sender)
            )
        );

        address finance = financeAddresses[rand % financeAddresses.length];

        usdt.safeTransfer(finance, received);

        emit Sell(msg.sender, amount, received, finance, bizId);
    }
}
