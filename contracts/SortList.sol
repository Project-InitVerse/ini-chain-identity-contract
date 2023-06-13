// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./InterfaceProvider.sol";

library SortLinkedList {
    struct List {
        IProvider head;
        IProvider tail;
        uint8 length;
        mapping(IProvider => IProvider) prev;
        mapping(IProvider => IProvider) next;
    }

    function improveRanking(List storage _list, IProvider _value) internal {
        //insert new
        if (_list.length == 0) {
            _list.head = _value;
            _list.tail = _value;
            _list.length++;
            return;
        }

        //already first
        if (_list.head == _value) {
            return;
        }

        IProvider _prev = _list.prev[_value];
        // not in list
        if (_prev == IProvider(address(0))) {
            //insert new
            _list.length++;

            if (address(_value).balance <= address(_list.tail).balance) {
                _list.prev[_value] = _list.tail;
                _list.next[_list.tail] = _value;
                _list.tail = _value;

                return;
            }

            _prev = _list.tail;
        } else {
            if (address(_value).balance <= address(_prev).balance) {
                return;
            }

            //remove from list
            _list.next[_prev] = _list.next[_value];
            if (_value == _list.tail) {
                _list.tail = _prev;
            } else {
                _list.prev[_list.next[_value]] = _list.prev[_value];
            }
        }

        while (_prev != IProvider(address(0)) && address(_value).balance > address(_prev).balance) {
            _prev = _list.prev[_prev];
        }

        if (_prev == IProvider(address(0))) {
            _list.next[_value] = _list.head;
            _list.prev[_list.head] = _value;
            _list.prev[_value] = IProvider(address(0));
            _list.head = _value;
        } else {
            _list.next[_value] = _list.next[_prev];
            _list.prev[_list.next[_prev]] = _value;
            _list.next[_prev] = _value;
            _list.prev[_value] = _prev;
        }
    }

    function lowerRanking(List storage _list, IProvider _value) internal {
        IProvider _next = _list.next[_value];
        if (_list.tail == _value || _next == IProvider(address(0)) || address(_next).balance <= address(_value).balance) {
            return;
        }

        //remove it
        _list.prev[_next] = _list.prev[_value];
        if (_list.head == _value) {
            _list.head = _next;
        } else {
            _list.next[_list.prev[_value]] = _next;
        }

        while (_next != IProvider(address(0)) && address(_next).balance > address(_value).balance) {
            _next = _list.next[_next];
        }

        if (_next == IProvider(address(0))) {
            _list.prev[_value] = _list.tail;
            _list.next[_value] = IProvider(address(0));

            _list.next[_list.tail] = _value;
            _list.tail = _value;
        } else {
            _list.next[_list.prev[_next]] = _value;
            _list.prev[_value] = _list.prev[_next];
            _list.next[_value] = _next;
            _list.prev[_next] = _value;
        }
    }

    function removeRanking(List storage _list, IProvider _value) internal {
        if (_list.head != _value && _list.prev[_value] == IProvider(address(0))) {
            //not in list
            return;
        }

        if (_list.tail == _value) {
            _list.tail = _list.prev[_value];
        }

        if (_list.head == _value) {
            _list.head = _list.next[_value];
        }

        IProvider _next = _list.next[_value];
        if (_next != IProvider(address(0))) {
            _list.prev[_next] = _list.prev[_value];
        }
        IProvider _prev = _list.prev[_value];
        if (_prev != IProvider(address(0))) {
            _list.next[_prev] = _list.next[_value];
        }

        _list.prev[_value] = IProvider(address(0));
        _list.next[_value] = IProvider(address(0));
        _list.length--;
    }
}
