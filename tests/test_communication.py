"""
Unit tests for communication protocol, JSON serialization, and server exchange.
"""

import json
import pytest
from python.communication.protocol import parse_message, serialize_message, MessageType
from python.communication.telemetry import TelemetryBuilder


def test_protocol_parsing_valid():
    raw = '{"type": "command", "action": "walk", "speed": 0.5}\n'
    success, data, err = parse_message(raw)
    assert success is True
    assert data["type"] == "command"
    assert data["action"] == "walk"
    assert data["speed"] == 0.5
    assert err is None


def test_protocol_parsing_invalid():
    raw = '{"type": "command", invalid json}\n'
    success, data, err = parse_message(raw)
    assert success is False
    assert data is None
    assert "JSON decode error" in err


def test_telemetry_builder():
    raw_sim = {
        "state": "STANDING",
        "balance": "STABLE",
        "roll": 1.2,
        "pitch": -0.5,
        "position": [0.0, 0.0, 0.85],
        "center_of_mass": [0.01, 0.0, 0.5],
        "walking": {"active": False},
        "sensors": {"front_distance": 2.5},
        "joints": {},
        "links": {},
        "obstacles": [],
    }
    packet = TelemetryBuilder.build(raw_sim)
    assert packet["type"] == MessageType.TELEMETRY
    assert packet["state"] == "STANDING"
    assert "timestamp" in packet

    # Verify serialization
    b = serialize_message(packet)
    assert b.endswith(b"\n")
    decoded = json.loads(b.decode("utf-8"))
    assert decoded["balance"] == "STABLE"
