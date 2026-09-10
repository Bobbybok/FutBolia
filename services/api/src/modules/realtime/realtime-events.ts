export const RealtimeEvents = {
  tournamentMessage: 'tournament:message',
  tournamentMessageDeleted: 'tournament:messageDeleted',
  tournamentChatCleared: 'tournament:chatCleared',
  teamMessage: 'team:message',
  teamMessageDeleted: 'team:messageDeleted',
  teamChatCleared: 'team:chatCleared',
  interTeamMessage: 'interTeam:message',
  interTeamMessageDeleted: 'interTeam:messageDeleted',
  interTeamChatCleared: 'interTeam:chatCleared',
  teamAssigned: 'team:assigned',
  teamCaptain: 'team:captain',
  privateMessage: 'private:message',
  privateMessageDeleted: 'private:messageDeleted',
  friendRequest: 'friend:request',
  friendAccepted: 'friend:accepted',
  tournamentInvite: 'tournament:invite',
  pickupInvite: 'pickup:invite',
  tournamentUpdated: 'tournament:updated',
  pickupUpdated: 'pickup:updated',
  lobbyChanged: 'lobby:changed',
} as const;

export type RealtimeEvent =
  (typeof RealtimeEvents)[keyof typeof RealtimeEvents];

export type PushPayload = {
  title: string;
  body: string;
  data: Record<string, string>;
};

export type NotifyUserInput = {
  userId: string;
  event: RealtimeEvent | string;
  payload: unknown;
  push?: PushPayload;
  skipPush?: boolean;
};
