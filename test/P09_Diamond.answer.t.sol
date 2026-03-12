// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Diamond} from "../src/diamond/Diamond.sol";
import {OwnerFacet} from "../src/diamond/OwnerFacet.sol";
import {CounterFacetV1} from "../src/diamond/CounterFacetV1.sol";
import {CounterFacetV2} from "../src/diamond/CounterFacetV2.sol";

interface Vm {
    function prank(address) external;
    function prank(address msgSender, address txOrigin) external;
}

interface IDiamondCut {
    function diamondCut(bytes4[] calldata selectors, address facet) external;
    function facetOf(bytes4 selector) external view returns (address);
}

interface IOwnerFacet {
    function diamondOwner() external view returns (address);
    function transferDiamondOwnership(address newOwner) external;
}

interface ICounterFacetV1 {
    function setValue(uint256 newValue) external;
    function getValue() external view returns (uint256);
    function version() external view returns (uint256);
}

interface ICounterFacetV2 is ICounterFacetV1 {
    function increment() external;
}

/// @notice Instructor solution for the student-facing Diamond practice test.
contract DiamondAnswerTest {
    Vm internal constant VM =
        Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    address internal constant ATTACKER = address(0xBEEF);
    uint256 internal constant INITIAL_VALUE = 7;

    function testDiamondCutAndReplaceFlow() external {
        Diamond diamond = new Diamond(address(this));
        OwnerFacet ownerFacet = new OwnerFacet();
        CounterFacetV1 counterV1 = new CounterFacetV1();

        bytes4[] memory ownerSelectors = _buildOwnerSelectors();
        bytes4[] memory counterSelectorsV1 = _buildCounterSelectorsV1();

        _registerInitialFacets(
            diamond,
            ownerSelectors,
            ownerFacet,
            counterSelectorsV1,
            counterV1
        );
        _assertInitialFlow(diamond);

        CounterFacetV2 counterV2 = new CounterFacetV2();
        bytes4[] memory counterSelectorsV2 = _buildCounterSelectorsV2();

        _assertAttackerCannotCut(diamond, counterSelectorsV2, counterV2);
        _assertInvalidFacetFails(diamond, counterSelectorsV2);
        _upgradeAsOwner(diamond, counterSelectorsV2, counterV2);
        _assertPostUpgradeFlow(diamond);
    }

    function _buildOwnerSelectors() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](2);
        selectors[0] = IOwnerFacet.diamondOwner.selector;
        selectors[1] = IOwnerFacet.transferDiamondOwnership.selector;
    }

    function _buildCounterSelectorsV1() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](3);
        selectors[0] = ICounterFacetV1.setValue.selector;
        selectors[1] = ICounterFacetV1.getValue.selector;
        selectors[2] = ICounterFacetV1.version.selector;
    }

    function _registerInitialFacets(
        Diamond diamond,
        bytes4[] memory ownerSelectors,
        OwnerFacet ownerFacet,
        bytes4[] memory counterSelectorsV1,
        CounterFacetV1 counterV1
    ) internal {
        IDiamondCut(address(diamond)).diamondCut(
            ownerSelectors,
            address(ownerFacet)
        );
        IDiamondCut(address(diamond)).diamondCut(
            counterSelectorsV1,
            address(counterV1)
        );
    }

    function _assertInitialFlow(Diamond diamond) internal {
        require(
            IOwnerFacet(address(diamond)).diamondOwner() == address(this),
            "owner facet must be registered"
        );

        ICounterFacetV1(address(diamond)).setValue(INITIAL_VALUE);
        require(
            ICounterFacetV1(address(diamond)).getValue() == INITIAL_VALUE,
            "set/get through V1 failed"
        );
        require(
            ICounterFacetV1(address(diamond)).version() == 1,
            "version should be 1 before upgrade"
        );
    }

    function _buildCounterSelectorsV2() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](4);
        selectors[0] = ICounterFacetV1.setValue.selector;
        selectors[1] = ICounterFacetV1.getValue.selector;
        selectors[2] = ICounterFacetV1.version.selector;
        selectors[3] = ICounterFacetV2.increment.selector;
    }

    function _assertAttackerCannotCut(
        Diamond diamond,
        bytes4[] memory selectors,
        CounterFacetV2 counterV2
    ) internal {
        VM.prank(ATTACKER, ATTACKER);
        (bool ok,) = address(diamond).call(
            abi.encodeWithSelector(
                IDiamondCut.diamondCut.selector,
                selectors,
                address(counterV2)
            )
        );
        require(!ok, "unauthorized diamondCut must fail");
    }

    function _assertInvalidFacetFails(
        Diamond diamond,
        bytes4[] memory selectors
    ) internal {
        (bool ok,) = address(diamond).call(
            abi.encodeWithSelector(
                IDiamondCut.diamondCut.selector,
                selectors,
                address(0xCAFE)
            )
        );
        require(!ok, "non-contract facet must fail");
    }

    function _upgradeAsOwner(
        Diamond diamond,
        bytes4[] memory selectors,
        CounterFacetV2 counterV2
    ) internal {
        IDiamondCut(address(diamond)).diamondCut(
            selectors,
            address(counterV2)
        );
    }

    function _assertPostUpgradeFlow(Diamond diamond) internal {
        require(
            ICounterFacetV2(address(diamond)).version() == 2,
            "version should be 2 after upgrade"
        );
        require(
            ICounterFacetV2(address(diamond)).getValue() == INITIAL_VALUE,
            "value must be preserved"
        );

        ICounterFacetV2(address(diamond)).increment();
        require(
            ICounterFacetV2(address(diamond)).getValue() == INITIAL_VALUE + 1,
            "increment failed"
        );

        (bool unknownSelectorOk,) = address(diamond).call(
            abi.encodeWithSignature("doesNotExist()")
        );
        require(!unknownSelectorOk, "unknown selector should revert");
    }
}
