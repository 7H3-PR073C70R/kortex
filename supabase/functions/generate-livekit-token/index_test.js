// supabase/functions/generate-livekit-token/index_test.js
// Unit and integration test suite for room-scoped LiveKit token generation and authorization.

import test from 'node:test';
import assert from 'node:assert/strict';

/**
 * Mock simulator of the LiveKit Token Generation handler logic
 */
async function handleGenerateLiveKitToken(req, env, mockDb) {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Content-Type': 'application/json',
  };

  const authHeader = req.headers.get('Authorization');
  if (!authHeader || !authHeader.toLowerCase().startsWith('bearer ')) {
    return {
      status: 401,
      body: { error: 'Unauthorized: Missing Bearer token' },
    };
  }

  const token = authHeader.replace(/^Bearer\s+/i, '').trim();
  const user = mockDb.users[token];
  if (!user) {
    return {
      status: 401,
      body: { error: 'Unauthorized: Invalid or expired session token' },
    };
  }

  const authenticatedUserId = user.id;
  const payload = req.body || {};
  const roomId = (payload.room_id || payload.roomId || '').trim();
  const requestedUserId = (payload.user_id || payload.userId || '').trim();

  if (requestedUserId && requestedUserId !== authenticatedUserId) {
    return {
      status: 403,
      body: { error: 'Forbidden: Cannot generate token for another user identity' },
    };
  }

  if (!roomId) {
    return {
      status: 400,
      body: { error: 'roomId is required' },
    };
  }

  // Simulated check_livekit_room_access RPC
  const accessResult = mockDb.checkLivekitRoomAccess(roomId, authenticatedUserId);
  if (!accessResult || !accessResult.allowed) {
    return {
      status: 403,
      body: {
        error: accessResult?.error || 'Forbidden: You are not authorized to access this room',
      },
    };
  }

  const displayName = accessResult.display_name || 'Scholar';
  const serverCanPublish = Boolean(accessResult.can_publish);
  const canPublishAudio = serverCanPublish && (payload.canPublish !== false);

  const apiKey = env.LIVEKIT_API_KEY;
  const apiSecret = env.LIVEKIT_API_SECRET;

  if (!apiKey || !apiSecret) {
    return {
      status: 503,
      body: { error: 'LiveKit server credentials are not configured on the backend.' },
    };
  }

  // Simulated token minting
  const mockJwt = `mock_livekit_jwt_for_${authenticatedUserId}_in_${roomId}_pub_${canPublishAudio}`;

  return {
    status: 200,
    body: {
      token: mockJwt,
      roomId,
      userId: authenticatedUserId,
      displayName,
      canPublish: canPublishAudio,
      role: accessResult.role || 'participant',
      roomType: accessResult.room_type,
      expiresIn: 21600,
    },
  };
}

// Setup mock database state
function createMockDb() {
  const users = {
    'alice-token': { id: 'usr-alice-111' },
    'bob-token': { id: 'usr-bob-222' },
    'charlie-token': { id: 'usr-charlie-333' },
  };

  const profiles = {
    'usr-alice-111': { display_name: 'Alice Scholar' },
    'usr-bob-222': { display_name: 'Bob Explorer' },
    'usr-charlie-333': { display_name: '' }, // tests fallback
  };

  const studyCircles = {
    'circle-private-101': { id: 'circle-private-101', creator_id: 'usr-alice-111' },
  };

  const studyCircleMembers = {
    'circle-private-101:usr-alice-111': { role: 'creator' },
  };

  const studyRooms = {
    'room-silent-201': {
      id: 'room-silent-201',
      created_by: 'usr-alice-111',
      is_silent_focus: true,
    },
    'room-open-202': {
      id: 'room-open-202',
      created_by: 'usr-bob-222',
      is_silent_focus: false,
    },
  };

  return {
    users,
    profiles,
    studyCircles,
    studyCircleMembers,
    studyRooms,
    checkLivekitRoomAccess(roomId, userId) {
      const profile = profiles[userId];
      const displayName = profile?.display_name || 'Scholar';

      // Study Circle / Pod
      if (studyCircles[roomId]) {
        const membership = studyCircleMembers[`${roomId}:${userId}`];
        if (membership) {
          return {
            allowed: true,
            room_type: 'study_pod',
            can_publish: true,
            display_name: displayName,
            role: membership.role,
          };
        }
        return {
          allowed: false,
          error: 'Forbidden: You are not an active member of this study pod',
          room_type: 'study_pod',
        };
      }

      // Study Room
      const room = studyRooms[roomId];
      if (room) {
        const isHost = room.created_by === userId;
        const canPublish = isHost || !room.is_silent_focus;
        return {
          allowed: true,
          room_type: 'study_room',
          can_publish: canPublish,
          display_name: displayName,
          role: isHost ? 'host' : 'participant',
        };
      }

      return {
        allowed: false,
        error: 'Room not found or access denied',
        room_type: 'unknown',
      };
    },
  };
}

const env = {
  LIVEKIT_API_KEY: 'mock_key',
  LIVEKIT_API_SECRET: 'mock_secret',
};

test('P2-06 · 1. Rejects request with missing or invalid Bearer authorization header', async () => {
  const mockDb = createMockDb();
  const req = {
    headers: new Map(),
    body: { roomId: 'room-silent-201' },
  };

  const res = await handleGenerateLiveKitToken(req, env, mockDb);
  assert.equal(res.status, 401);
  assert.match(res.body.error, /Missing Bearer token/);
});

test('P2-06 · 2. Rejects request attempting to spoof another user identity', async () => {
  const mockDb = createMockDb();
  const req = {
    headers: new Map([['Authorization', 'Bearer alice-token']]),
    body: {
      roomId: 'room-silent-201',
      userId: 'usr-bob-222', // Alice trying to impersonate Bob
    },
  };

  const res = await handleGenerateLiveKitToken(req, env, mockDb);
  assert.equal(res.status, 403);
  assert.match(res.body.error, /Cannot generate token for another user identity/);
});

test('P2-06 · 3. Rejects non-member attempting to mint token for private study pod (Acceptance Criteria)', async () => {
  const mockDb = createMockDb();
  // Bob is NOT a member of circle-private-101
  const req = {
    headers: new Map([['Authorization', 'Bearer bob-token']]),
    body: {
      roomId: 'circle-private-101',
    },
  };

  const res = await handleGenerateLiveKitToken(req, env, mockDb);
  assert.equal(res.status, 403);
  assert.match(res.body.error, /You are not an active member of this study pod/);
});

test('P2-06 · 4. Allows active member to mint token for private study pod with publish rights', async () => {
  const mockDb = createMockDb();
  // Alice is the creator/member of circle-private-101
  const req = {
    headers: new Map([['Authorization', 'Bearer alice-token']]),
    body: {
      roomId: 'circle-private-101',
      username: 'HackerName', // should be ignored
    },
  };

  const res = await handleGenerateLiveKitToken(req, env, mockDb);
  assert.equal(res.status, 200);
  assert.equal(res.body.userId, 'usr-alice-111');
  assert.equal(res.body.displayName, 'Alice Scholar'); // Authoritative, not 'HackerName'
  assert.equal(res.body.canPublish, true);
  assert.equal(res.body.role, 'creator');
  assert.equal(res.body.roomType, 'study_pod');
  assert.ok(res.body.token);
});

test('P2-06 · 5. Restricts publishing privileges for participants in silent focus rooms', async () => {
  const mockDb = createMockDb();
  // Bob joins Alice's silent focus room (room-silent-201)
  const req = {
    headers: new Map([['Authorization', 'Bearer bob-token']]),
    body: {
      roomId: 'room-silent-201',
      canPublish: true, // Client wants to speak, but room is silent!
    },
  };

  const res = await handleGenerateLiveKitToken(req, env, mockDb);
  assert.equal(res.status, 200);
  assert.equal(res.body.canPublish, false); // Server overrides client input
  assert.equal(res.body.role, 'participant');
  assert.equal(res.body.roomType, 'study_room');
});

test('P2-06 · 6. Grants host publishing rights in silent focus room', async () => {
  const mockDb = createMockDb();
  // Alice is the creator/host of room-silent-201
  const req = {
    headers: new Map([['Authorization', 'Bearer alice-token']]),
    body: {
      roomId: 'room-silent-201',
    },
  };

  const res = await handleGenerateLiveKitToken(req, env, mockDb);
  assert.equal(res.status, 200);
  assert.equal(res.body.canPublish, true);
  assert.equal(res.body.role, 'host');
});

test('P2-06 · 7. Respects voluntary client listen-only in open room', async () => {
  const mockDb = createMockDb();
  // Alice joins open room (room-open-202) where canPublish is normally allowed, but explicitly opts out
  const req = {
    headers: new Map([['Authorization', 'Bearer alice-token']]),
    body: {
      roomId: 'room-open-202',
      canPublish: false,
    },
  };

  const res = await handleGenerateLiveKitToken(req, env, mockDb);
  assert.equal(res.status, 200);
  assert.equal(res.body.canPublish, false);
});

test('P2-06 · 8. Returns 403 when requesting non-existent room', async () => {
  const mockDb = createMockDb();
  const req = {
    headers: new Map([['Authorization', 'Bearer alice-token']]),
    body: {
      roomId: 'non-existent-room-999',
    },
  };

  const res = await handleGenerateLiveKitToken(req, env, mockDb);
  assert.equal(res.status, 403);
  assert.match(res.body.error, /Room not found or access denied/);
});
