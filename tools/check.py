#!/usr/bin/env python3
"""Run artifact tests and, when supplied, real Luau compilation/runtime checks."""
from __future__ import annotations

import argparse
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def run(command: list[str]) -> None:
    subprocess.run(command, cwd=ROOT, check=True)


def data_harness() -> str:
    """Inject a deterministic Roblox service mock around the UNCHANGED DataService."""
    service = (ROOT / "src/server/DataService.luau").read_text()
    preamble = r'''
local Balance = require("../src/shared/Balance")
local Config = require("../src/shared/Config")
local Profile = require("../src/shared/Profile")
local count = 0
local function check(value, message) count += 1; assert(value, message) end
local function copy(t)
    if type(t) ~= "table" then return t end
    local out = {}; for k, v in t do out[k] = copy(v) end; return out
end
local store = { values = {}, fail = false, repeatCallback = false, afterTransform = nil }
function store:UpdateAsync(key, transform)
    if self.fail then error("simulated network failure") end
    if self.repeatCallback then transform(copy(self.values[key])) end
    local nextValue = transform(copy(self.values[key]))
    if nextValue == nil then return nil end
    if self.afterTransform then self.afterTransform() end
    self.values[key] = copy(nextValue)
    return copy(nextValue)
end
local function signal() return { Connect = function() end } end
local studio = true
local players = { PlayerRemoving = signal() }
local services = {
    Players = players,
    DataStoreService = { GetDataStore = function() return store end },
    RunService = { IsStudio = function() return studio end },
    HttpService = { GenerateGUID = function() return "TEST_SESSION" end },
}
local fakeGame = { JobId = "TEST", ReplicatedStorage = { ZumbiShared = { Balance = "Balance", Config = "Config", Profile = "Profile" } } }
function fakeGame:GetService(name) return assert(services[name], name) end
function fakeGame:BindToClose() end
local nodeMethods = {}
function nodeMethods:FindFirstChild(name) return self.children[name] end
local instance = {}
function instance.new(class)
    return setmetatable({ children = {}, ClassName = class }, {
        __index = function(t, k) return nodeMethods[k] or t.children[k] end,
        __newindex = function(t, k, v)
            rawset(t, k, v)
            if k == "Parent" and v then v.children[t.Name] = t end
        end,
    })
end
local function player(id)
    local p = instance.new("Player"); p.Name = "Test" .. id; p.UserId = id; p.Parent = instance.new("Players"); p.attrs = {}
    function p:SetAttribute(k, v) self.attrs[k] = v end
    function p:GetAttribute(k) return self.attrs[k] end
    function p:Kick(reason) self.kicked = reason end
    return p
end
local tasks = { wait = function() end, spawn = function() end }
local function moduleRequire(name)
    if name == "Balance" then return Balance elseif name == "Config" then return Config elseif name == "Profile" then return Profile end
    error("Unknown module " .. tostring(name))
end
local function loadData(game, require, task, Instance, warn)
'''
    assertions = r'''
end
local warnings = {}
local Data = loadData(fakeGame, moduleRequire, tasks, instance, function(m) table.insert(warnings, m) end)
local p = player(10)
Data.load(p)
check(p:GetAttribute("DataReady") == true, "Profile must become ready")
check(p:GetAttribute("DataPersistent") == true, "Successful store is persistent")
check(p:GetAttribute("Coins") == Balance.StartingCoins, "First load starting coins")
Data.award(p, 80, 2)
check(p:GetAttribute("Coins") == 200, "Gameplay earnings")
check(p.leaderstats.Abates.Value == 2, "Leaderboard tracks kills")
check(Data.spend(p, 201) == false, "Cannot overspend")
check(Data.spend(p, -50) == false, "Negative spending rejected")
check(Data.spend(p, 30) == true and p:GetAttribute("Coins") == 170, "Atomic spend")
check(Data.spend(p, 0 / 0) == false and p:GetAttribute("Coins") == 170, "NaN spending is rejected without mutation")
check(Data.award(p, math.huge, 1) == false and p.leaderstats.Abates.Value == 2, "Invalid award cannot partly grant kills")
check(Data.receipt(p, {}, { Grant = "Coins", Amount = 1 }) == false, "Malformed receipt ID rejected")
check(Data.receipt(p, "invalid-product", { Grant = "Other", Amount = 10 }) == false, "Unknown entitlement rejected")
check(Data.receipt(p, "negative-product", { Grant = "Coins", Amount = -10 }) == false, "Negative entitlement rejected")
check(Data.cosmetic(p, "does-not-exist") == nil, "Reject unknown cosmetic")
Data.award(p, 1000)
check(Data.cosmetic(p, "Ember") == true, "Buy cosmetic")
local skinBalance = p:GetAttribute("Coins")
check(Data.cosmetic(p, "Ember") == true and p:GetAttribute("Coins") == skinBalance, "Equipping owned skin is free")

local product = { Grant = "Coins", Amount = 500 }
store.repeatCallback = true -- Roblox may rerun UpdateAsync transforms.
check(Data.receipt(p, "purchase-a", product), "Receipt must persist")
check(p:GetAttribute("Coins") == skinBalance + 500, "Product grants exact coins")
check(store.values.u_10.Receipts["purchase-a"] == true, "Receipt ID stored with benefit")
check(Data.receipt(p, "purchase-a", product), "Duplicate receipt acknowledged")
check(p:GetAttribute("Coins") == skinBalance + 500, "Duplicate receipt never grants twice")

local beforeFailure = p:GetAttribute("Coins")
store.fail = true
check(Data.receipt(p, "purchase-b", product) == false, "Failed persistence must not acknowledge purchase")
check(p:GetAttribute("Coins") == beforeFailure, "Failed receipt must not grant unsaved benefit")
check(Data.save(p, false) == false, "Store errors must fail save")
store.fail = false
check(Data.receipt(p, "purchase-b", product), "Retry succeeds after connection recovers")
check(p:GetAttribute("Coins") == beforeFailure + 500, "Retry grants once")

local beforeConcurrent = p:GetAttribute("Coins")
store.afterTransform = function() Data.award(p, 37) end
check(Data.receipt(p, "purchase-c", product), "Concurrent receipt succeeds")
store.afterTransform = nil
check(p:GetAttribute("Coins") == beforeConcurrent + 537, "Earnings during yielding store request are retained")

check(Data.receipt(p, "revive-a", { Grant = "Revives", Amount = 1 }), "Revive granted")
check(Data.useRevive(p) and p:GetAttribute("Revives") == 0, "Consume revive exactly once")
check(Data.useRevive(p) == false, "No negative revive balance")
check(Data.receipt(p, "boost-a", { Grant = "Boost", Amount = 900 }), "Boost grant")
local firstBoost = p:GetAttribute("BoostUntil")
check(firstBoost >= os.time() + 899, "Boost lasts 15 minutes")
check(Data.receipt(p, "boost-b", { Grant = "Boost", Amount = 900 }), "Second boost grant")
check(p:GetAttribute("BoostUntil") == firstBoost + 900, "Boosts stack duration")

Data.record(p, 9, false); Data.record(p, 4, false); Data.record(p, 15, true)
check(p:GetAttribute("BestWave") == 15 and p:GetAttribute("Wins") == 1, "Progress records best wave and victories")
local finalCoins = p:GetAttribute("Coins")
check(Data.save(p, true), "Release persisted")
check(Data.Profiles[p] == nil and store.values.u_10.Session == nil, "Release clears session lease")
local rejoined = player(10); Data.load(rejoined)
check(rejoined:GetAttribute("Coins") == finalCoins, "Coins survive rejoin")
check(rejoined:GetAttribute("Skin") == "Ember", "Cosmetic survives rejoin")
check(Data.receipt(rejoined, "purchase-a", product), "Historical receipt acknowledged after rejoin")
check(rejoined:GetAttribute("Coins") == finalCoins, "Historical receipt not granted twice")

store.values.u_20 = { Session = { Id = "OTHER_SERVER", Until = os.time() + 150 } }
local locked = player(20); Data.load(locked)
check(locked.kicked ~= nil and not locked:GetAttribute("DataReady"), "Active session lock protects profile")
store.values.u_21 = { Coins = "bad", Session = { Id = "OTHER_SERVER" } }
local damaged = player(21); Data.load(damaged)
check(damaged:GetAttribute("DataReady") and not damaged.kicked, "Malformed lease no longer breaks profile loading")
check(damaged:GetAttribute("Coins") == Balance.StartingCoins, "Malformed stored balance repaired")

store.fail = true
local offline = player(30); Data.load(offline)
check(offline:GetAttribute("DataReady") and offline:GetAttribute("DataPersistent") == false, "Studio fallback is temporary")
check(Data.receipt(offline, "offline-purchase", product) == false, "Temporary profiles cannot acknowledge purchases")
studio = false
local liveFailure = player(40); Data.load(liveFailure)
check(liveFailure.kicked ~= nil and not liveFailure:GetAttribute("DataReady"), "Live failures do not overwrite saved data")
print("PASS DataService: " .. count .. " assertions (mocked Roblox services)")
'''
    return preamble + service + assertions


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", default=shutil.which("luau"))
    parser.add_argument("--compiler", default=shutil.which("luau-compile"))
    args = parser.parse_args()
    run([sys.executable, "-m", "unittest", "discover", "-s", "tests", "-p", "test_*.py", "-v"])
    if args.compiler:
        paths = sorted(ROOT.joinpath("src").rglob("*.luau"))
        for path in paths:
            subprocess.run([args.compiler, "--null", str(path)], cwd=ROOT, check=True, stdout=subprocess.DEVNULL)
        print(f"PASS Luau compiler: {len(paths)} source files", flush=True)
    else:
        print("UNRUN Luau compilation: supply --compiler /path/to/luau-compile", flush=True)
    if args.luau:
        run([args.luau, "tests/balance.test.luau"])
        run([args.luau, "tests/profile.test.luau"])
        harness = ROOT / "build" / "data.test.luau"
        harness.parent.mkdir(exist_ok=True)
        harness.write_text(data_harness())
        run([args.luau, str(harness)])
    else:
        print("UNRUN Luau runtime tests: supply --luau /path/to/luau", flush=True)
