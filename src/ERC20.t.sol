// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.6.7;

import {DSTest} from "ds-test/test.sol";
import {MintableERC20} from "./ERC20.sol";
import {Math} from "./Math.sol";
import {AMM} from "./AMM.sol";

contract TestMintableERC20 is DSTest {
    MintableERC20 erc20;
    function setUp() public {
        erc20 = new MintableERC20();
    }

    function prove_balance(uint supply, address rich, address poor) public {
        if (rich == poor) return;

        erc20.mint(rich, supply);

        assertEq(erc20.balanceOf(rich), supply);
        assertEq(erc20.balanceOf(poor), 0);
    }

    function prove_transfer(uint supply, address dst, uint amt) public {
        if (amt > supply) return;         // no underflow
        if (dst == address(this)) return; // ignore self transfer

        erc20.mint(address(this), supply);
        erc20.transfer(dst, amt);

        assertEq(erc20.balanceOf(dst), amt);
        assertEq(erc20.balanceOf(address(this)), supply - amt);
    }
}

contract TestAMM is DSTest, Math {
    MintableERC20 token0;
    MintableERC20 token1;
    AMM pair;

    function setUp() public {
        token0 = new MintableERC20();
        token1 = new MintableERC20();
        pair = new AMM(address(token0), address(token1));

        token0.mint(address(this), uint(-1));
        token1.mint(address(this), uint(-1));

        token0.approve(address(pair), uint(-1));
        token1.approve(address(pair), uint(-1));
    }

    function prove_join_initial(uint amt0, uint amt1) public {
        if (amt0 == 0 || amt1 == 0) return; // ensure sufficient input

        pair.join(amt0, amt1);
        uint shares_initial = pair.balanceOf(address(this));
        assertEq(shares_initial, min(amt0, amt1));
        assertEq(token0.balanceOf(address(pair)), amt0);
        assertEq(token1.balanceOf(address(pair)), amt1);
    }

    function prove_k(uint112 joinAmt0, uint112 joinAmt1, uint112 swapAmt) public {
        if (joinAmt0 == 0 || joinAmt1 == 0) return;               // ensure sufficient input
        if (swapAmt > joinAmt0 || swapAmt > joinAmt1) return;     // ensure sufficient liqudity
        //if ((joinAmt0 * joinAmt1) / joinAmt1 != joinAmt0) return; // no mul overflow

        pair.join(joinAmt0, joinAmt1);

        uint preK = mul(token0.balanceOf(address(pair)), token1.balanceOf(address(pair)));
        pair.swap(address(token0), address(token1), swapAmt);
        uint postK = mul(token0.balanceOf(address(pair)), token1.balanceOf(address(pair)));

        assertTrue(postK >= preK);
    }
}