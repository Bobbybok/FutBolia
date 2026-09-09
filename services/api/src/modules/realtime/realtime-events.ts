export const RealtimeEvents = {
  tournamentMessage: 'tournament:message',
  tournamentMessageDeleted: 'tournament:messageDeleted',
  tournamentChatCleared: 'tournament:chatCleared',
  privateMessage: 'private:message',
  privateMessageDeleted: 'private:messageDeleted',
  friendRequest: 'friend:request',
  friendAccepted: 'friend:accepted',
  tournamentInvite: 'tournament:invite',
  pickupInvite: 'pickup:invite',
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
