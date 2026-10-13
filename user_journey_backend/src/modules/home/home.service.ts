import { computeStreak } from '../../lib/time.js';
import { todayTaskLessonId } from '../journey/journey.rules.js';
import type { JourneyService } from '../journey/journey.service.js';
import type { HomeRepository } from './home.repository.js';

export interface HomeDto {
  user: { displayName: string; healthPointsTotal: number; streakDays: number };
  todayTask: { lessonId: string; lessonTitle: string; nodeId: string; statusTitle: string } | null;
}

export class HomeService {
  constructor(
    private readonly repo: HomeRepository,
    private readonly journey: JourneyService,
    private readonly timeZone: string,
    private readonly now: () => Date = () => new Date(),
  ) {}

  async home(userId: string): Promise<HomeDto> {
    const [user, dates, snapshot] = await Promise.all([
      this.repo.user(userId),
      this.repo.completionDates(userId, this.timeZone),
      this.journey.snapshot(userId),
    ]);
    const taskId = todayTaskLessonId(snapshot.orderedNodes, snapshot.states);
    const task = taskId ? snapshot.lessons.get(taskId)! : null;
    return {
      user: {
        displayName: user.display_name,
        healthPointsTotal: user.health_points_total,
        streakDays: computeStreak(dates, this.now(), this.timeZone),
      },
      todayTask: task
        ? {
            lessonId: task.lesson.id,
            lessonTitle: task.lesson.title,
            nodeId: task.node.id,
            statusTitle: task.status.title,
          }
        : null,
    };
  }
}
