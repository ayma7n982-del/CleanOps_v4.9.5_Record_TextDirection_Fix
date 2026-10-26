import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue, DocumentReference, DocumentData } from 'firebase-admin/firestore';
import { randomBytes } from 'crypto';

initializeApp();
const db = getFirestore();
const auth = getAuth();

const MANAGEMENT_ROLES = ['donor_manager', 'jsc_coordinator', 'municipality_coordinator'] as const;
const WORKFORCE_ROLES = ['worker', 'group_supervisor'] as const;
type Role = typeof MANAGEMENT_ROLES[number] | typeof WORKFORCE_ROLES[number];

function isManagementRole(role: string): role is typeof MANAGEMENT_ROLES[number] {
  return (MANAGEMENT_ROLES as readonly string[]).includes(role);
}

function isWorkforceRole(role: string): role is typeof WORKFORCE_ROLES[number] {
  return (WORKFORCE_ROLES as readonly string[]).includes(role);
}

async function requireActor(uid: string) {
  const snap = await db.collection('users').doc(uid).get();
  if (!snap.exists) throw new HttpsError('permission-denied', 'Actor profile is missing.');
  const actor = snap.data() ?? {};
  if (actor.isActive === false) throw new HttpsError('permission-denied', 'Actor account is inactive.');
  return actor;
}

export const resolveLoginEmail = onCall({ region: 'us-central1' }, async (request) => {
  const raw = String((request.data as Record<string, unknown> | undefined)?.username ?? '').trim().toLowerCase();
  if (!raw) throw new HttpsError('invalid-argument', 'Username is required.');
  if (raw.includes('@')) return { email: raw };
  const snap = await db.collection('users')
    .where('username', '==', raw)
    .limit(1)
    .get();
  if (snap.empty) {
    return { email: `${raw}@solidwaste.local` };
  }
  const data = snap.docs[0].data();
  const email = String(data.email ?? '').trim().toLowerCase();
  return { email: email || `${raw}@solidwaste.local` };
});

export const requestPasswordReset = onCall({ region: 'us-central1' }, async (request) => {
  const raw = String((request.data as Record<string, unknown> | undefined)?.username ?? '').trim().toLowerCase();
  if (!raw) throw new HttpsError('invalid-argument', 'Username is required.');
  let email = raw.includes('@') ? raw : '';
  if (!email) {
    const snap = await db.collection('users')
      .where('username', '==', raw)
      .limit(1)
      .get();
    if (!snap.empty) {
      const profile = snap.docs[0];
      const data = profile.data();
      email = String(data.email ?? '').trim().toLowerCase();
      if (!email) {
        try {
          const authProfile = await auth.getUser(profile.id);
          email = String(authProfile.email ?? '').trim().toLowerCase();
        } catch (_) {}
      }
    }
    if (!email) email = `${raw}@solidwaste.local`;
  }

  let authUser;
  try {
    authUser = await auth.getUserByEmail(email);
  } catch (e: any) {
    if (e?.code === 'auth/user-not-found') {
      return { sent: true };
    }
    throw new HttpsError('internal', 'Unable to check the account.');
  }

  if (authUser.disabled) return { sent: true };

  const apiKey = process.env.FIREBASE_WEB_API_KEY ?? 'AIzaSyAa8b1275kDi-xxkiDbKVSOD8U0FvmTJBc';
  const response = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=${encodeURIComponent(apiKey)}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ requestType: 'PASSWORD_RESET', email }),
  });

  if (!response.ok) {
    const body = await response.text();
    console.error('Password reset delivery failed:', body);
    throw new HttpsError('failed-precondition', 'Password reset email could not be sent.');
  }
  return { sent: true };
});

export const provisionWorkforceUser = onCall({ region: 'us-central1' }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Authentication is required.');
  const actor = await requireActor(request.auth.uid);
  if (actor.role !== 'municipality_coordinator') {
    throw new HttpsError('permission-denied', 'Only the Municipality Coordinator may provision workforce accounts.');
  }
  const data = request.data as Record<string, unknown>;
  return createUserAccount({
    actorUid: request.auth.uid,
    actorRole: String(actor.role),
    data,
    allowedRoles: WORKFORCE_ROLES,
  });
});

export const provisionManagementUser = onCall({ region: 'us-central1' }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Authentication is required.');
  const actor = await requireActor(request.auth.uid);
  if (actor.role !== 'donor_manager') {
    throw new HttpsError('permission-denied', 'Only Level 4 may provision management accounts.');
  }
  const data = request.data as Record<string, unknown>;
  const role = String(data.role ?? '');
  if (!isManagementRole(role)) {
    throw new HttpsError('invalid-argument', 'Only Level 2, Level 3, or Level 4 accounts may be created here.');
  }
  return createUserAccount({
    actorUid: request.auth.uid,
    actorRole: String(actor.role),
    data,
    allowedRoles: MANAGEMENT_ROLES,
  });
});

async function createUserAccount({
  actorUid,
  actorRole,
  data,
  allowedRoles,
}: {
  actorUid: string;
  actorRole: string;
  data: Record<string, unknown>;
  allowedRoles: readonly Role[];
}) {
  const name = String(data.name ?? '').trim();
  const username = String(data.username ?? '').trim().toLowerCase();
  const role = String(data.role ?? '') as Role;
  const phone = String(data.phone ?? '').trim();
  const requestedEmail = String(data.email ?? '').trim().toLowerCase();
  const employeeId = String(data.employeeId ?? '').trim();
  const jobTitle = String(data.jobTitle ?? '').trim();
  const notes = String(data.notes ?? '').trim();
  const requestedPassword = String(data.password ?? '');
  const scope = String(data.scope ?? 'assigned_only');
  const cycleId = String(data.cycleId ?? '').trim();
  const groupId = String(data.groupId ?? '').trim();

  if (!name || !username || !allowedRoles.includes(role)) {
    throw new HttpsError('invalid-argument', 'Incomplete account data.');
  }
  if (isWorkforceRole(role) && (!cycleId || !groupId)) {
    throw new HttpsError('invalid-argument', 'Workforce accounts require cycleId and groupId.');
  }
  if (cycleId) {
    const cycle = await db.collection('work_cycles').doc(cycleId).get();
    if (!cycle.exists || cycle.data()?.status !== 'active') {
      throw new HttpsError('failed-precondition', 'The selected work cycle is not active.');
    }
  }

  const email = requestedEmail || (username.includes('@') ? username : `${username}@solidwaste.local`);
  const temporaryPassword = requestedPassword || generatePassword();
  if (temporaryPassword.length < 8) throw new HttpsError('invalid-argument', 'Password must be at least 8 characters.');
  let authUser;
  try {
    authUser = await auth.createUser({
      email,
      password: temporaryPassword,
      displayName: name,
      phoneNumber: phone || undefined,
      disabled: false,
    });
  } catch (e: any) {
    if (e?.code === 'auth/email-already-exists') throw new HttpsError('already-exists', 'Username already exists.');
    throw new HttpsError('internal', e?.message ?? 'Unable to create account.');
  }

  try {
    const userRef = db.collection('users').doc(authUser.uid);
    const auditRef = db.collection('audit').doc();
    const batch = db.batch();
    batch.set(userRef, {
      id: authUser.uid,
      username: username.replace(/@solidwaste\.local$/i, ''),
      email: authUser.email,
      name,
      role,
      scope,
      phone,
      employeeId,
      jobTitle,
      notes,
      groupId: groupId || null,
      municipalityCoordinatorId: isWorkforceRole(role) && actorRole === 'municipality_coordinator' ? actorUid : null,
      cycleId: cycleId || null,
      isActive: true,
      status: 'active',
      createdBy: actorUid,
      createdByRole: actorRole,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    batch.set(auditRef, {
      actorId: actorUid,
      operation: 'PROVISION_USER',
      targetId: authUser.uid,
      after: { username, role, cycleId: cycleId || null, groupId: groupId || null },
      createdAt: new Date().toISOString(),
      timestamp: FieldValue.serverTimestamp(),
      immutable: true,
    });
    await batch.commit();
  } catch (e: any) {
    await auth.deleteUser(authUser.uid).catch(() => undefined);
    throw new HttpsError('internal', e?.message ?? 'Unable to create user profile and audit record.');
  }

  return { uid: authUser.uid, username: username.replace(/@solidwaste\.local$/i, ''), email, temporaryPassword, passwordWasProvided: requestedPassword.length > 0, role };
}



export const deleteManagedUser = onCall({ region: 'us-central1', timeoutSeconds: 60 }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Authentication is required.');
  const actor = await requireActor(request.auth.uid);
  const userId = String(request.data?.userId ?? '').trim();
  if (!userId) throw new HttpsError('invalid-argument', 'userId is required.');
  if (userId === request.auth.uid) throw new HttpsError('failed-precondition', 'لا يمكن حذف الحساب الحالي.');

  const targetRef = db.collection('users').doc(userId);
  const targetSnap = await targetRef.get();
  if (!targetSnap.exists) throw new HttpsError('not-found', 'المستخدم غير موجود.');
  const target = targetSnap.data() ?? {};
  const targetRole = String(target.role ?? '');
  const workforce = targetRole === 'worker' || targetRole === 'group_supervisor';
  const allowed = actor.role === 'donor_manager'
    || (actor.role === 'municipality_coordinator'
      && workforce
      && String(target.municipalityCoordinatorId ?? '') === request.auth.uid);
  if (!allowed) throw new HttpsError('permission-denied', 'لا تملك صلاحية حذف هذا المستخدم.');

  try {
    await auth.deleteUser(userId);
  } catch (e: any) {
    // Simulation profiles and old imported profiles may not have an Auth account.
    // The Firestore profile still must be removed from the operational list.
    if (e?.code !== 'auth/user-not-found') {
      throw new HttpsError('internal', e?.message ?? 'تعذر حذف حساب Firebase Authentication.');
    }
  }

  await targetRef.delete();
  await db.collection('audit').add({
    actorId: request.auth.uid,
    operation: 'DELETE_USER',
    targetId: userId,
    before: { name: target.name ?? '', role: targetRole },
    createdAt: new Date().toISOString(),
    timestamp: FieldValue.serverTimestamp(),
    immutable: true,
  });
  return { ok: true, userId, deletedAuth: true };
});


// ---------------------------------------------------------------------------
// TEMPORARY CYCLE 11 SIMULATION SEEDER
// ---------------------------------------------------------------------------
// This seeder is intentionally isolated from the normal application write
// paths. Every document created by the simulation is tagged with
// `isSimulation: true`, which makes cleanup safe and deterministic.
const SIMULATION_FLAG = true;
const SIMULATION_PLACEHOLDER_IMAGE = 'https://via.placeholder.com/150';

function simulationBase(extra: Record<string, unknown> = {}) {
  return {
    isSimulation: SIMULATION_FLAG,
    simulationName: 'Cycle 11 • Bani Suheila • October 2026',
    ...extra,
  };
}

export const runCycle11Simulation = onCall({ region: 'us-central1', timeoutSeconds: 120 }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Authentication is required.');
  const actor = await requireActor(request.auth.uid);
  if (actor.role !== 'donor_manager') {
    throw new HttpsError('permission-denied', 'Only Level 4 may run the temporary simulation.');
  }

  // Prevent duplicate seed runs. The function is temporary and should never
  // silently create a second simulation set.
  const existing = await db.collection('work_cycles')
    .where('isSimulation', '==', true)
    .limit(100)
    .get();
  if (existing.docs.some((doc) => doc.data().cycleNumber === 11)) {
    throw new HttpsError('already-exists', 'بيانات محاكاة الدورة 11 موجودة مسبقاً. احذفها أولاً ثم أعد التشغيل.');
  }

  const municipalityId = 'sim_municipality_bani_suheila';
  const cycleId = 'sim_cycle_11_oct_2026';
  const municipalityName = 'بلدية بني سهيلا';
  // If a real L2 account for Bani Suheila exists, bind the simulation to it
  // so the same data is visible from the municipality dashboard under the
  // existing read rules. Otherwise keep the simulation isolated.
  const requestedCoordinatorId = String(request.data?.municipalityCoordinatorId ?? '').trim();
  let targetCoordinatorId = requestedCoordinatorId;
  if (!targetCoordinatorId) {
    const candidate = await db.collection('users')
      .where('role', '==', 'municipality_coordinator')
      .limit(100).get();
    const match = candidate.docs.find((d) => String(d.data().municipalityName ?? d.data().scope ?? '').trim() === municipalityName);
    if (match) targetCoordinatorId = match.id;
  }
  const accessMunicipalityId = targetCoordinatorId || municipalityId;
  const startDate = new Date('2026-10-01T00:00:00+03:00');
  const endDate = new Date('2026-10-20T23:59:59+03:00');

  const dumpsites = [
    {
      id: 'sim_dumpsite_asdaa',
      nameAr: 'مكب أصداء',
      nameEn: 'Asdaa',
      capacity: 20,
      fillPercentage: 0,
    },
    {
      id: 'sim_dumpsite_al_aqsa',
      nameAr: 'مكب الأقصى',
      nameEn: 'Al-Aqsa',
      capacity: 20,
      fillPercentage: 0,
    },
  ];

  const groups = Array.from({ length: 5 }, (_, index) => {
    const n = index + 1;
    return { id: `sim_cycle11_group_${String(n).padStart(2, '0')}`, number: n, name: `المجموعة ${n}` };
  });

  const writes: Array<{ ref: DocumentReference; data: DocumentData }> = [];
  const add = (ref: DocumentReference, data: DocumentData) => {
    writes.push({ ref, data: simulationBase(data) });
  };

  // 1) Municipality.
  add(db.collection('municipalities').doc(municipalityId), {
    id: municipalityId,
    name: municipalityName,
    nameAr: municipalityName,
    nameEn: 'Bani Suheila Municipality',
    status: 'active',
    createdAt: FieldValue.serverTimestamp(),
  });
  // Mirror the municipality into the existing operations stream so the app
  // can display simulation municipalities without opening a new Firestore
  // rule surface for the municipalities collection.
  add(db.collection('operations').doc('sim_cycle11_municipality_index'), {
    id: 'sim_cycle11_municipality_index',
    _entity: 'municipality',
    name: municipalityName,
    nameAr: municipalityName,
    nameEn: 'Bani Suheila Municipality',
    municipalityId,
    municipalityName,
    status: 'active',
    createdAt: FieldValue.serverTimestamp(),
  });

  // 2) Cycle 11 — October 2026.
  add(db.collection('work_cycles').doc(cycleId), {
    id: cycleId,
    name: 'الدورة 11 - أكتوبر 2026',
    cycleNumber: 11,
    month: 10,
    monthName: 'أكتوبر 2026',
    startDate,
    endDate,
    status: 'active',
    municipalityId,
    municipalityName,
    createdBy: request.auth.uid,
    createdAt: FieldValue.serverTimestamp(),
  });
  add(db.collection('operations').doc('sim_cycle11_cycle_index'), {
    id: 'sim_cycle11_cycle_index',
    _entity: 'cycle',
    name: 'الدورة 11 - أكتوبر 2026',
    cycleNumber: 11,
    month: 10,
    monthName: 'أكتوبر 2026',
    cycleId,
    municipalityId,
    municipalityName,
    status: 'active',
    startDate: startDate.toISOString(),
    endDate: endDate.toISOString(),
    createdAt: startDate.toISOString(),
  });

  // 3) Dumpsites.
  for (const site of dumpsites) {
    add(db.collection('dumpsites').doc(site.id), {
      id: site.id,
      name: site.nameAr,
      nameAr: site.nameAr,
      nameEn: site.nameEn,
      code: site.nameEn.toUpperCase().replace(/[^A-Z]/g, ''),
      location: municipalityName,
      capacity: site.capacity,
      fillPercentage: site.fillPercentage,
      isActive: true,
      municipalityId: accessMunicipalityId,
      sourceMunicipalityId: municipalityId,
      municipalityName,
      createdBy: request.auth.uid,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  }

  // 4) Five containers.
  const containerCoordinates = [
    [31.3475, 34.3042],
    [31.3490, 34.3061],
  ];
  for (let i = 0; i < 2; i++) {
    const id = `sim_cycle11_container_${String(i + 1).padStart(2, '0')}`;
    add(db.collection('containers').doc(id), {
      id,
      locationName: 'شارع الرشيد، خان يونس',
      gpsCoordinates: { lat: containerCoordinates[i][0], lng: containerCoordinates[i][1] },
      latitude: containerCoordinates[i][0],
      longitude: containerCoordinates[i][1],
      status: 'empty',
      issueStatus: 'none',
      municipalityId: accessMunicipalityId,
      municipalityName,
      sourceMunicipalityId: municipalityId,
      groupId: groups[i].id,
      groupName: groups[i].name,
      feedbackNotes: '',
      imageUrl: SIMULATION_PLACEHOLDER_IMAGE,
      imageUrls: [SIMULATION_PLACEHOLDER_IMAGE],
      updatedAt: new Date().toISOString(),
      updatedBy: request.auth.uid,
      createdAt: new Date().toISOString(),
    });
  }

  // 5) Groups + workers. Simulation workers are Firestore-only profiles;
  // no Firebase Authentication accounts are created.
  for (const group of groups) {
    add(db.collection('operations').doc(group.id), {
      id: group.id,
      _entity: 'group',
      name: group.name,
      groupName: group.name,
      groupNumber: group.number,
      number: group.number,
      status: 'active',
      municipalityId: accessMunicipalityId,
      municipalityName,
      municipalityCoordinatorId: targetCoordinatorId || 'simulation',
      cycleId,
      cycleName: 'الدورة 11 - أكتوبر 2026',
      createdBy: request.auth.uid,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    const supervisorId = `sim_cycle11_group${group.number}_supervisor`;
    add(db.collection('users').doc(supervisorId), {
      id: supervisorId,
      username: supervisorId,
      email: `${supervisorId}@simulation.cleanops.local`,
      name: `مشرف ميداني ${group.number}`,
      role: 'group_supervisor',
      scope: municipalityName,
      groupId: group.id,
      groupName: group.name,
      municipalityCoordinatorId: targetCoordinatorId || 'simulation',
      municipalityName,
      cycleId,
      cycleName: 'الدورة 11 - أكتوبر 2026',
      isActive: true,
      status: 'active',
      jobTitle: 'مشرف ميداني',
      employeeId: `SIM-G${group.number}-SUP`,
      notes: 'حساب محاكاة - لا يملك Firebase Authentication.',
      createdBy: request.auth.uid,
      createdByRole: actor.role,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    for (let w = 1; w <= 7; w++) {
      const workerId = `sim_cycle11_group${group.number}_collector${String(w).padStart(2, '0')}`;
      add(db.collection('users').doc(workerId), {
        id: workerId,
        username: workerId,
        email: `${workerId}@simulation.cleanops.local`,
        name: `عامل جمع أساسي ${group.number}-${w}`,
        role: 'worker',
        scope: municipalityName,
        groupId: group.id,
        groupName: group.name,
        municipalityCoordinatorId: targetCoordinatorId || 'simulation',
        municipalityName,
        cycleId,
        isActive: true,
        status: 'active',
        jobTitle: 'عامل جمع أساسي',
        employeeId: `SIM-G${group.number}-W${String(w).padStart(2, '0')}`,
        notes: 'حساب محاكاة - لا يملك Firebase Authentication.',
        createdBy: request.auth.uid,
        createdByRole: actor.role,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    for (let w = 1; w <= 2; w++) {
      const workerId = `sim_cycle11_group${group.number}_animalcart${w}`;
      add(db.collection('users').doc(workerId), {
        id: workerId,
        username: workerId,
        email: `${workerId}@simulation.cleanops.local`,
        name: `عامل كارة بحمار ${group.number}-${w}`,
        role: 'worker',
        scope: municipalityName,
        groupId: group.id,
        groupName: group.name,
        municipalityCoordinatorId: targetCoordinatorId || 'simulation',
        municipalityName,
        cycleId,
        isActive: true,
        status: 'active',
        jobTitle: 'عامل كارة بحمار',
        employeeId: `SIM-G${group.number}-A${w}`,
        notes: 'حساب محاكاة - لا يملك Firebase Authentication.',
        createdBy: request.auth.uid,
        createdByRole: actor.role,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
  }

  // 6) Trips: 20 days. Group 1 = 5/day, then +2 trips for each next group.
  // Each cart trip carries 10 tons; GPS and placeholder photos are attached.
  let tripSequence = 0;
  for (let day = 0; day < 20; day++) {
    const tripDate = new Date(startDate.getTime() + day * 24 * 60 * 60 * 1000);
    for (const group of groups) {
      const dailyTrips = 5 + (group.number - 1) * 2;
      for (let t = 1; t <= dailyTrips; t++) {
        tripSequence++;
        const destination = Math.random() < 0.5 ? dumpsites[0] : dumpsites[1];
        const tripId = `sim_cycle11_trip_${String(tripSequence).padStart(4, '0')}`;
        const supervisorId = `sim_cycle11_group${group.number}_supervisor`;
        add(db.collection('operations').doc(tripId), {
          id: tripId,
          _entity: 'trip',
          title: `نقلة ${tripSequence}`,
          operation: 'trip',
          status: 'completed',
          tripNumber: t,
          tripSequence,
          date: tripDate.toISOString(),
          createdAt: tripDate.toISOString(),
          municipalityId,
          municipalityName,
          cycleId,
          cycleName: 'الدورة 11 - أكتوبر 2026',
          groupId: group.id,
          groupName: group.name,
          supervisorId,
          supervisorName: `مشرف ميداني ${group.number}`,
          sourceLocation: 'شارع الرشيد، خان يونس',
          destinationDumpsiteId: destination.id,
          destinationDumpsiteName: destination.nameAr,
          destination: destination.nameAr,
          volumeTons: 10,
          estimatedQuantity: 10,
          unit: 'طن',
          cartType: 'animal_cart',
          alternative: true,
          gpsCoordinates: { lat: 31.3475 + (group.number * 0.001) + (day * 0.0001), lng: 34.3042 + (t * 0.0001) },
          latitude: 31.3475 + (group.number * 0.001) + (day * 0.0001),
          longitude: 34.3042 + (t * 0.0001),
          imageUrls: [SIMULATION_PLACEHOLDER_IMAGE],
          imageUrl: SIMULATION_PLACEHOLDER_IMAGE,
          notes: 'نقلة محاكاة للدورة 11.',
          createdBy: request.auth.uid,
        });
      }
    }
  }

  // Firestore batch limit is 500. The current seed is below that limit, but
  // chunking keeps this temporary utility safe if the dataset grows later.
  for (let i = 0; i < writes.length; i += 450) {
    const batch = db.batch();
    for (const item of writes.slice(i, i + 450)) batch.set(item.ref, item.data);
    await batch.commit();
  }

  return {
    ok: true,
    isSimulation: true,
    municipality: municipalityName,
    cycleId,
    cycleNumber: 11,
    days: 20,
    groups: groups.length,
    supervisors: groups.length,
    primaryWorkers: groups.length * 7,
    animalCartWorkers: groups.length * 2,
    containers: 2,
    dumpsites: 2,
    trips: tripSequence,
    volumeTons: tripSequence,
  };
});

export const deleteSimulationData = onCall({ region: 'us-central1', timeoutSeconds: 120 }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Authentication is required.');
  const actor = await requireActor(request.auth.uid);
  if (actor.role !== 'donor_manager') {
    throw new HttpsError('permission-denied', 'Only Level 4 may delete simulation data.');
  }

  let deleted = 0;
  const collections = await db.listCollections();
  for (const collection of collections) {
    while (true) {
      const snap = await collection.where('isSimulation', '==', true).limit(450).get();
      if (snap.empty) break;
      const batch = db.batch();
      snap.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
      deleted += snap.size;
      if (snap.size < 450) break;
    }
  }

  return { ok: true, deleted, isSimulationCleanup: true };
});

export const syncAiUserState = onDocumentWritten('users/{uid}', async (event) => {
  const before = event.data?.before.exists ? (event.data.before.data() ?? {}) : null;
  const after = event.data?.after.exists ? (event.data.after.data() ?? {}) : null;
  if (!before && !after) return;
  const ref = db.collection('ai_state').doc('command_center');
  const updates: Record<string, unknown> = {
    updatedAt: FieldValue.serverTimestamp(),
    lastUserEvent: {
      uid: event.params.uid,
      action: before && after ? 'updated' : after ? 'created' : 'deleted',
      role: after?.role ?? before?.role ?? null,
      isActive: after?.isActive !== false,
    },
  };
  if (!before && after) {
    updates.totalUsers = FieldValue.increment(1);
    updates.activeUsers = FieldValue.increment(after.isActive === false ? 0 : 1);
    if (after.role) updates[`roles.${String(after.role)}`] = FieldValue.increment(1);
  } else if (before && !after) {
    updates.totalUsers = FieldValue.increment(-1);
    updates.activeUsers = FieldValue.increment(before.isActive === false ? 0 : -1);
    if (before.role) updates[`roles.${String(before.role)}`] = FieldValue.increment(-1);
  } else if (before && after) {
    const beforeActive = before.isActive !== false;
    const afterActive = after.isActive !== false;
    if (beforeActive !== afterActive) updates.activeUsers = FieldValue.increment(afterActive ? 1 : -1);
    if (before.role !== after.role) {
      if (before.role) updates[`roles.${String(before.role)}`] = FieldValue.increment(-1);
      if (after.role) updates[`roles.${String(after.role)}`] = FieldValue.increment(1);
    }
  }
  await ref.set(updates, { merge: true });
});

function generatePassword(): string {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#';
  const bytes = randomBytes(12);
  return Array.from(bytes, (b: number) => alphabet[b % alphabet.length]).join('');
}
