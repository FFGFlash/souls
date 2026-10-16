--!strict
-- Server entry point. Movement is client-authoritative (the client owns its character's physics),
-- so the server only has supporting work for now.

local LockOnTagger = require(script.LockOnTagger)

LockOnTagger.Start()
