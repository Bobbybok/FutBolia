import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ForumService } from './forum.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { CreateForumPostDto } from './dto/create-forum-post.dto';
import { CreateForumReplyDto } from './dto/create-forum-reply.dto';

@Controller()
export class ForumController {
  constructor(private readonly forumService: ForumService) {}

  @Get('tournaments/:tournamentId/forum/posts')
  @UseGuards(JwtAuthGuard)
  listPosts(
    @Param('tournamentId') tournamentId: string,
    @CurrentUser() user: AuthUser,
  ) {
    return this.forumService.listPosts(tournamentId, user.id);
  }

  @Post('tournaments/:tournamentId/forum/posts')
  @UseGuards(JwtAuthGuard)
  createPost(
    @Param('tournamentId') tournamentId: string,
    @CurrentUser() user: AuthUser,
    @Body() dto: CreateForumPostDto,
  ) {
    return this.forumService.createPost(tournamentId, user.id, dto);
  }

  @Get('forum/posts/:postId')
  @UseGuards(JwtAuthGuard)
  getPost(@Param('postId') postId: string, @CurrentUser() user: AuthUser) {
    return this.forumService.getPost(postId, user.id);
  }

  @Post('forum/posts/:postId/replies')
  @UseGuards(JwtAuthGuard)
  createReply(
    @Param('postId') postId: string,
    @CurrentUser() user: AuthUser,
    @Body() dto: CreateForumReplyDto,
  ) {
    return this.forumService.createReply(postId, user.id, dto);
  }

  @Delete('forum/posts/:postId')
  @UseGuards(JwtAuthGuard)
  @HttpCode(200)
  deletePost(@Param('postId') postId: string, @CurrentUser() user: AuthUser) {
    return this.forumService.deletePost(postId, user.id);
  }

  @Delete('forum/replies/:replyId')
  @UseGuards(JwtAuthGuard)
  @HttpCode(200)
  deleteReply(
    @Param('replyId') replyId: string,
    @CurrentUser() user: AuthUser,
  ) {
    return this.forumService.deleteReply(replyId, user.id);
  }
}
