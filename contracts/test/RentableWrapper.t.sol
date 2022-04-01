// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {DSTest} from "ds-test/test.sol";

import {TestNFT} from "./utils/TestNFT.sol";

import {CheatCodes} from "./SharedSetup.t.sol";

import {ERC721ReadOnlyProxy} from "../ERC721ReadOnlyProxy.sol";
import {ERC721ReadOnlyProxyInitializable} from "../ERC721ReadOnlyProxyInitializable.sol";

import {ProxyFactoryInitializable} from "../utils/ProxyFactoryInitializable.sol";

contract RentableWrapper is DSTest {
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);

    TestNFT testNFT;

    address deployer;

    function setUp() public virtual {
        deployer = cheats.addr(1);

        cheats.startPrank(deployer);

        testNFT = new TestNFT();

        cheats.stopPrank();
    }

    function testWrapper() public virtual {
        cheats.startPrank(deployer);

        testNFT.mint(deployer, 123);

        string memory prefix = "z";
        ERC721ReadOnlyProxyInitializable wrapper = new ERC721ReadOnlyProxyInitializable(
                address(testNFT),
                prefix
            );

        assertEq(
            wrapper.symbol(),
            string(abi.encodePacked(prefix, testNFT.symbol()))
        );
        assertEq(
            wrapper.name(),
            string(abi.encodePacked(prefix, testNFT.name()))
        );
        assertEq(wrapper.tokenURI(123), testNFT.tokenURI(123));

        address minter = cheats.addr(2);
        address user = cheats.addr(3);
        wrapper.setMinter(minter);
        assertEq(wrapper.getMinter(), minter);

        cheats.stopPrank();
        cheats.startPrank(minter);
        uint256 tokenId = 50;
        wrapper.mint(user, tokenId);

        cheats.stopPrank();
        cheats.startPrank(user);

        cheats.expectRevert(bytes("Only minter"));
        wrapper.mint(user, tokenId + 1);

        cheats.expectRevert(bytes("Only minter"));
        wrapper.burn(tokenId);

        cheats.stopPrank();
        cheats.startPrank(minter);
        wrapper.burn(tokenId);
        cheats.expectRevert("ERC721: owner query for nonexistent token");
        wrapper.ownerOf(tokenId);

        cheats.stopPrank();
    }

    function testWrapperProxyInit() public {
        ProxyFactoryInitializable pfi = new ProxyFactoryInitializable();
        TestNFT t1 = new TestNFT();
        TestNFT t2 = new TestNFT();

        address owner = cheats.addr(2);

        ERC721ReadOnlyProxyInitializable wrapper = new ERC721ReadOnlyProxyInitializable(
                address(t1),
                "w"
            );

        string memory proxyPrefix = "j";
        bytes memory data = abi.encodeWithSelector(
            ERC721ReadOnlyProxyInitializable.initialize.selector,
            address(t2),
            proxyPrefix,
            owner
        );

        (address proxy, ) = pfi.deployMinimal(address(wrapper), data);

        ERC721ReadOnlyProxy proxyInstance = ERC721ReadOnlyProxy(proxy);

        assertEq(
            proxyInstance.symbol(),
            string(abi.encodePacked(proxyPrefix, t2.symbol()))
        );
        assertEq(
            proxyInstance.name(),
            string(abi.encodePacked(proxyPrefix, t2.name()))
        );
        assertEq(proxyInstance.owner(), owner);
    }

    function testWrapperProxyDoubleInit() public {
        ProxyFactoryInitializable pfi = new ProxyFactoryInitializable();
        TestNFT t1 = new TestNFT();
        TestNFT t2 = new TestNFT();

        address owner = cheats.addr(2);

        ERC721ReadOnlyProxyInitializable wrapper = new ERC721ReadOnlyProxyInitializable(
                address(t1),
                "w"
            );

        string memory proxyPrefix = "j";
        bytes memory data = abi.encodeWithSelector(
            ERC721ReadOnlyProxyInitializable.initialize.selector,
            address(t2),
            proxyPrefix,
            owner
        );

        pfi.deployMinimal(address(wrapper), data);

        cheats.expectRevert(
            bytes("Initializable: contract is already initialized")
        );
        wrapper.initialize(address(t2), "k", owner);

        cheats.expectRevert(
            bytes("Initializable: contract is already initialized")
        );
        wrapper.initialize(address(t1), "l", deployer);
    }
}
