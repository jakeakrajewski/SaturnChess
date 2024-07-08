const std = @import("std");
const brd = @import("../Board/Board.zig");
const map = @import("../Maps/Maps.zig");
const bit = @import("../BitManipulation/BitManipulation.zig");
const sqr = @import("../Board/Square.zig");

pub fn GenerateMoves(list: *std.ArrayList(Move), board: *brd.Board, side: u1) !void {
    const kingBoard = if (side == 0) board.wKing else board.bKing;
    const kingSquare: u6 = @intCast(bit.LeastSignificantBit(kingBoard));
    const attackers = board.isSquareAttacked(kingSquare, side);
    const pinMask = GetPinMask(board.*, side);
    const checkMask = GetCheckMask(board.*, side);

    if (attackers > 1) {
        try KingMoves(list, board, side);
    } else {
        try PawnMoves(list, board, side, checkMask, pinMask);
        try KnightMoves(list, board, side, checkMask, pinMask);
        try BishopMoves(list, board, side, checkMask, pinMask);
        try RookMoves(list, board, side, checkMask, pinMask);
        try QueenMoves(list, board, side, checkMask, pinMask);
        try KingMoves(list, board, side);

        if (attackers == 0) {
            try CastleMoves(list, board, side);
        }
    }
}

pub fn GetPinMask(board: brd.Board, side: u1) u64 {
    var b = board;
    var bishops = if (side == 0) board.bBishops else board.wBishops;
    var rooks = if (side == 0) board.bRooks else board.wRooks;
    var queens = if (side == 0) board.bQueens else board.wQueens;
    const kingBoard = if (side == 0) board.wKing else board.bKing;
    const pieces = if (side == 0) b.wPieces() else b.bPieces();
    const oPieces = if (side == 0) b.bPieces() else b.wPieces();
    const kingSquare: u6 = @intCast(bit.LeastSignificantBit(kingBoard));

    var bishopMask: u64 = 0;
    var rookMask: u64 = 0;
    var queenBishopMask: u64 = 0;
    var queenRookMask: u64 = 0;

    while (bishops > 0) {
        const source: u6 = @intCast(bit.LeastSignificantBit(bishops));
        const sourceBoard: u64 = @as(u64, 1) << source;
        const bishopCheck = (sourceBoard & map.GetBishopAttacks(kingSquare, b.allPieces()));

        if (bishopCheck > 0) {
            bit.PopBit(&bishops, try sqr.Square.fromIndex(source));
            continue;
        }

        if ((sourceBoard & map.GetBishopAttacks(kingSquare, oPieces)) > 0) {
            bishopMask |= map.GetBishopAttacks(source, pieces);
        }
        bit.PopBit(&bishops, try sqr.Square.fromIndex(source));
        bishopMask &= map.GetBishopAttacks(kingSquare, sourceBoard);
    }

    while (rooks > 0) {
        const source: u6 = @intCast(bit.LeastSignificantBit(rooks));
        const sourceBoard: u64 = @as(u64, 1) << source;
        const rookCheck = (sourceBoard & map.GetRookAttacks(kingSquare, b.allPieces()));

        if (rookCheck > 0) {
            bit.PopBit(&rooks, try sqr.Square.fromIndex(source));
            continue;
        }

        if ((sourceBoard & map.GetRookAttacks(kingSquare, oPieces)) > 0) {
            rookMask |= map.GetRookAttacks(source, pieces);
        }
        bit.PopBit(&rooks, try sqr.Square.fromIndex(source));
        rookMask &= map.GetRookAttacks(kingSquare, sourceBoard);
    }

    while (queens > 0) {
        const source: u6 = @intCast(bit.LeastSignificantBit(queens));
        const sourceBoard: u64 = @as(u64, 1) << source;

        const bishopCheck = (sourceBoard & map.GetBishopAttacks(kingSquare, b.allPieces()));
        const rookCheck = (sourceBoard & map.GetRookAttacks(kingSquare, b.allPieces()));

        if (bishopCheck > 0 or rookCheck > 0) {
            bit.PopBit(&queens, try sqr.Square.fromIndex(source));
            continue;
        }

        if ((sourceBoard & map.GetBishopAttacks(kingSquare, oPieces)) > 0) {
            queenBishopMask |= map.GetBishopAttacks(source, pieces);
        }
        if ((sourceBoard & map.GetRookAttacks(kingSquare, oPieces)) > 0) {
            queenRookMask |= map.GetRookAttacks(source, pieces);
        }

        bit.PopBit(&queens, try sqr.Square.fromIndex(source));
        queenRookMask &= map.GetRookAttacks(kingSquare, sourceBoard);
        queenBishopMask &= map.GetBishopAttacks(kingSquare, sourceBoard);
    }

    return bishopMask | rookMask | queenRookMask | queenBishopMask;
}

pub fn GetCheckMask(board: brd.Board, side: u1) u64 {
    const oSide: u1 = if (side == 0) 1 else 0;
    var pawns = if (side == 0) board.bPawns else board.wPawns;
    var knights = if (side == 0) board.bKnights else board.wKnights;
    var bishops = if (side == 0) board.bBishops else board.wBishops;
    var rooks = if (side == 0) board.bRooks else board.wRooks;
    var queens = if (side == 0) board.bQueens else board.wQueens;
    const kingBoard = if (side == 0) board.wKing else board.bKing;
    const kingSquare: u6 = @intCast(bit.LeastSignificantBit(kingBoard));
    var b = board;

    var mask: u64 = 0;

    while (pawns > 0) {
        const source: u6 = @intCast(bit.LeastSignificantBit(pawns));
        const attackMask = map.pawnAttacks[oSide][source];
        const sourceBoard: u64 = @as(u64, 1) << source;
        if ((attackMask & kingBoard) > 0) mask |= sourceBoard;
        bit.PopBit(&pawns, try sqr.Square.fromIndex(source));
    }
    while (knights > 0) {
        const source: u6 = @intCast(bit.LeastSignificantBit(knights));
        const attackMask = map.knightAttacks[source];
        const sourceBoard: u64 = @as(u64, 1) << source;
        if ((attackMask & kingBoard) > 0) mask |= sourceBoard;
        bit.PopBit(&knights, try sqr.Square.fromIndex(source));
    }
    while (bishops > 0) {
        const source: u6 = @intCast(bit.LeastSignificantBit(bishops));
        const kingSliders = map.GetBishopAttacks(kingSquare, bishops);
        const attackMask = map.GetBishopAttacks(source, b.allPieces());
        const sourceBoard: u64 = (@as(u64, 1) << source) | attackMask;
        if ((attackMask & kingBoard) > 0) mask |= sourceBoard & kingSliders;
        bit.PopBit(&bishops, try sqr.Square.fromIndex(source));
    }
    while (rooks > 0) {
        const source: u6 = @intCast(bit.LeastSignificantBit(rooks));
        const kingSliders = map.GetRookAttacks(kingSquare, rooks);
        const attackMask = map.GetRookAttacks(source, b.allPieces());
        const sourceBoard: u64 = (@as(u64, 1) << source) | attackMask;
        if ((attackMask & kingBoard) > 0) mask |= sourceBoard & kingSliders;
        bit.PopBit(&rooks, try sqr.Square.fromIndex(source));
    }
    while (queens > 0) {
        const source: u6 = @intCast(bit.LeastSignificantBit(queens));
        var kingSliders = map.GetBishopAttacks(kingSquare, queens);
        var attackMask = map.GetBishopAttacks(source, b.allPieces());
        var sourceBoard: u64 = (@as(u64, 1) << source) | attackMask;
        if ((attackMask & kingBoard) > 0) mask |= sourceBoard & kingSliders;
        kingSliders = map.GetRookAttacks(kingSquare, queens);
        attackMask = map.GetRookAttacks(source, b.allPieces());
        sourceBoard = (@as(u64, 1) << source) | attackMask;
        if ((attackMask & kingBoard) > 0) mask |= sourceBoard & kingSliders;
        bit.PopBit(&queens, try sqr.Square.fromIndex(source));
    }

    return mask;
}

pub fn PawnMoves(list: *std.ArrayList(Move), board: *brd.Board, side: u1, checkMask: u64, pinMask: u64) !void {
    const piece = if (side == 0) brd.Pieces.P else brd.Pieces.p;
    const direction: i8 = if (side == 0) -8 else 8;
    const promotionRank: u4 = if (side == 0) 7 else 2;
    const doubleRank: u4 = if (side == 0) 2 else 7;
    var bitBoard: u64 = if (side == 0) board.wPawns else board.bPawns;
    const opponentPieces: u64 = if (side == 0) board.bPieces() else board.wPieces();
    const kingBoard = if (side == 0) board.wKing else board.bKing;
    const kingSquare: u6 = @intCast(bit.LeastSignificantBit(kingBoard));

    while (bitBoard > 0) {
        const source: u6 = @intCast(bit.LeastSignificantBit(bitBoard));
        const epSquare: u6 = @truncate(bit.LeastSignificantBit(board.enPassantSquare));
        bit.PopBit(&bitBoard, try sqr.Square.fromIndex(source));
        if (source == 64) break;

        const rank: u4 = @intCast(8 - (source / 8));
        var target: u6 = @intCast(source + direction);
        if (target < 0) continue;

        const sourceBoard = @as(u64, 1) << source;
        var targetBoard = @as(u64, 1) << target;
        const doubleBoard = if (rank == doubleRank) @as(u64, 1) << @intCast(target + direction) else 0;
        var singlePossible = true;
        var doublePossible = true;
        var piecePinned = false;

        if (checkMask > 0) {
            if ((checkMask & targetBoard) == 0) singlePossible = false;
            if ((checkMask & doubleBoard) == 0) doublePossible = false;
        }

        if ((pinMask & sourceBoard) > 0) {
            var boardCopy = board.*;
            if (side == 0) {
                bit.PopBit(&boardCopy.wPawns, try sqr.Square.fromIndex(source));
                bit.SetBit(&boardCopy.wPawns, try sqr.Square.fromIndex(target));
            } else {
                bit.PopBit(&boardCopy.bPawns, try sqr.Square.fromIndex(source));
                bit.SetBit(&boardCopy.bPawns, try sqr.Square.fromIndex(target));
            }

            if (boardCopy.isSquareAttacked(kingSquare, side) > 0) piecePinned = true;
        }

        var pieceAtTarget: bool = targetBoard & board.allPieces() > 0;
        if (!pieceAtTarget and !piecePinned) {
            if (rank == promotionRank and singlePossible) {
                try list.append(Move{ .source = source, .target = target, .piece = piece, .promotion = .Q });
                try list.append(Move{ .source = source, .target = target, .piece = piece, .promotion = .R });
                try list.append(Move{ .source = source, .target = target, .piece = piece, .promotion = .B });
                try list.append(Move{ .source = source, .target = target, .piece = piece, .promotion = .N });
            } else {
                if (singlePossible) {
                    try list.append(Move{ .source = source, .target = target, .piece = piece });
                }

                if (rank == doubleRank and doublePossible) {
                    // Double pawn push
                    pieceAtTarget = bit.GetBit(board.allPieces(), @intCast(target + direction)) > 0;
                    if (!pieceAtTarget) {
                        try list.append(Move{ .source = source, .target = @intCast(target + direction), .piece = piece, .isDoublePush = true });
                    }
                }
            }
        }

        var attackMap = map.pawnAttacks[side][source];
        attackMap &= (opponentPieces | board.enPassantSquare);
        while (attackMap > 0) {
            target = @intCast(bit.LeastSignificantBit(attackMap));
            targetBoard = @as(u64, 1) << target;
            bit.PopBit(&attackMap, try sqr.Square.fromIndex(@intCast(target)));

            if (checkMask > 0) {
                const blockerChecker = (checkMask & targetBoard) > 0;

                if (!blockerChecker) {
                    var boardCopy = board.*;
                    if (side == 0) {
                        bit.PopBit(&boardCopy.wPawns, try sqr.Square.fromIndex(source));
                        bit.SetBit(&boardCopy.wPawns, try sqr.Square.fromIndex(target));
                        if (target == epSquare) {
                            const epTarget = if (side == 0) epSquare + 8 else epSquare - 8;
                            bit.PopBit(&boardCopy.bPawns, try sqr.Square.fromIndex(epTarget));
                        }
                        bit.PopBit(&boardCopy.bPawns, try sqr.Square.fromIndex(target));
                        bit.PopBit(&boardCopy.bKnights, try sqr.Square.fromIndex(target));
                        bit.PopBit(&boardCopy.bBishops, try sqr.Square.fromIndex(target));
                        bit.PopBit(&boardCopy.bRooks, try sqr.Square.fromIndex(target));
                        bit.PopBit(&boardCopy.bQueens, try sqr.Square.fromIndex(target));
                    } else {
                        bit.PopBit(&boardCopy.bPawns, try sqr.Square.fromIndex(source));
                        bit.SetBit(&boardCopy.bPawns, try sqr.Square.fromIndex(target));
                        if (target == epSquare) {
                            const epTarget = if (side == 0) epSquare + 8 else epSquare - 8;
                            bit.PopBit(&boardCopy.wPawns, try sqr.Square.fromIndex(epTarget));
                        }
                        bit.PopBit(&boardCopy.wPawns, try sqr.Square.fromIndex(target));
                        bit.PopBit(&boardCopy.wKnights, try sqr.Square.fromIndex(target));
                        bit.PopBit(&boardCopy.wBishops, try sqr.Square.fromIndex(target));
                        bit.PopBit(&boardCopy.wRooks, try sqr.Square.fromIndex(target));
                        bit.PopBit(&boardCopy.wQueens, try sqr.Square.fromIndex(target));
                    }

                    if (boardCopy.isSquareAttacked(kingSquare, side) > 0) continue;
                }
            }

            if ((pinMask & sourceBoard) > 0) {
                var boardCopy = board.*;
                if (side == 0) {
                    bit.PopBit(&boardCopy.wPawns, try sqr.Square.fromIndex(source));
                    bit.SetBit(&boardCopy.wPawns, try sqr.Square.fromIndex(target));
                    if (target == epSquare) {
                        const epTarget = if (side == 0) epSquare + 8 else epSquare - 8;
                        bit.PopBit(&boardCopy.bPawns, try sqr.Square.fromIndex(epTarget));
                    }
                    bit.PopBit(&boardCopy.bPawns, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.bKnights, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.bBishops, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.bRooks, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.bQueens, try sqr.Square.fromIndex(target));
                } else {
                    bit.PopBit(&boardCopy.bPawns, try sqr.Square.fromIndex(source));
                    bit.SetBit(&boardCopy.bPawns, try sqr.Square.fromIndex(target));
                    if (target == epSquare) {
                        const epTarget = if (side == 0) epSquare + 8 else epSquare - 8;
                        bit.PopBit(&boardCopy.wPawns, try sqr.Square.fromIndex(epTarget));
                    }
                    bit.PopBit(&boardCopy.wPawns, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.wKnights, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.wBishops, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.wRooks, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.wQueens, try sqr.Square.fromIndex(target));
                }

                if (boardCopy.isSquareAttacked(kingSquare, side) > 0) continue;
            }

            if (rank == promotionRank) {
                try list.append(Move{ .source = source, .target = target, .piece = piece, .promotion = .Q, .isCapture = true });
                try list.append(Move{ .source = source, .target = target, .piece = piece, .promotion = .R, .isCapture = true });
                try list.append(Move{ .source = source, .target = target, .piece = piece, .promotion = .B, .isCapture = true });
                try list.append(Move{ .source = source, .target = target, .piece = piece, .promotion = .N, .isCapture = true });
            } else {
                if (target == epSquare) {
                    const epTarget = if (side == 0) epSquare + 8 else epSquare - 8;
                    var boardCopy = board.*;

                    if (side == 0) {
                        bit.PopBit(&boardCopy.wPawns, try sqr.Square.fromIndex(source));
                        bit.SetBit(&boardCopy.wPawns, try sqr.Square.fromIndex(target));
                        bit.PopBit(&boardCopy.bPawns, try sqr.Square.fromIndex(epTarget));
                    } else {
                        bit.PopBit(&boardCopy.bPawns, try sqr.Square.fromIndex(source));
                        bit.SetBit(&boardCopy.bPawns, try sqr.Square.fromIndex(target));
                        bit.PopBit(&boardCopy.wPawns, try sqr.Square.fromIndex(epTarget));
                    }

                    if (boardCopy.isSquareAttacked(kingSquare, side) == 0) {
                        try list.append(Move{ .source = source, .target = target, .piece = piece, .isCapture = true, .isEnPassant = true });
                    }
                } else {
                    try list.append(Move{ .source = source, .target = target, .piece = piece, .isCapture = true });
                }
            }
        }
    }
}

// pub fn PawnMoves(list: *std.ArrayList(Move), board: *brd.Board, side: u1) !void {
//     const piece = if (side == 0) brd.Pieces.P else brd.Pieces.p;
//     const direction: i8 = if (side == 0) -8 else 8;
//     const promotionRank: u64 = if (side == 0) map.RANK_7 else map.RANK_2;
//     const doubleRank: u64 = if (side == 0) map.RANK_2 else map.RANK_7;
//     const bitBoard: u64 = if (side == 0) board.wPawns else board.bPawns;
//     const opponentPieces: u64 = if (side == 0) board.bPieces() else board.wPieces();
//     const epSquare: u6 = @truncate(bit.LeastSignificantBit(board.enPassantSquare));
//
//     var singlePushes: u64 = bitBoard & ~promotionRank;
//     var doublePushes: u64 = undefined;
//     var promotions: u64 = bitBoard & promotionRank;
//     var captures: u64 = singlePushes;
//     var capturePromotions: u64 = promotions;
//
//     if (side == 0) {
//         singlePushes &= ~(board.allPieces() << 8);
//         doublePushes = (singlePushes & doubleRank) & ~(board.allPieces() << 16);
//         promotions &= ~(board.allPieces() << 8);
//         captures &= (((opponentPieces | board.enPassantSquare) << 9) | ((opponentPieces | board.enPassantSquare) << 7));
//         capturePromotions &= ((opponentPieces << 9) | (opponentPieces << 7));
//     } else {
//         singlePushes &= ~(board.allPieces() >> 8);
//         doublePushes = (singlePushes & doubleRank) & ~(board.allPieces() >> 16);
//         promotions &= ~(board.allPieces() >> 8);
//         captures &= (((opponentPieces | board.enPassantSquare) >> 9) | ((opponentPieces | board.enPassantSquare) >> 7));
//         capturePromotions &= ((opponentPieces >> 9) | (opponentPieces >> 7));
//     }
//
//     while (singlePushes > 0) {
//         const source: u6 = @intCast(bit.LeastSignificantBit(singlePushes));
//         bit.PopBit(&singlePushes, try sqr.Square.fromIndex(source));
//         const target: u6 = @intCast(source + direction);
//         try list.append(Move{ .source = source, .target = target, .piece = piece });
//     }
//
//     while (doublePushes > 0) {
//         const source: u6 = @intCast(bit.LeastSignificantBit(doublePushes));
//         bit.PopBit(&doublePushes, try sqr.Square.fromIndex(source));
//         const target: u6 = @intCast(source + (direction * 2));
//         try list.append(Move{ .source = source, .target = @intCast(target), .piece = piece, .isDoublePush = true });
//     }
//
//     while (promotions > 0) {
//         const source: u6 = @intCast(bit.LeastSignificantBit(promotions));
//         bit.PopBit(&promotions, try sqr.Square.fromIndex(source));
//         const target: u6 = @intCast(source + direction);
//         try list.append(Move{ .source = source, .target = target, .piece = piece, .promotion = .Q });
//         try list.append(Move{ .source = source, .target = target, .piece = piece, .promotion = .R });
//         try list.append(Move{ .source = source, .target = target, .piece = piece, .promotion = .B });
//         try list.append(Move{ .source = source, .target = target, .piece = piece, .promotion = .N });
//     }
//
//     while (capturePromotions > 0) {
//         const source: u6 = @intCast(bit.LeastSignificantBit(capturePromotions));
//         bit.PopBit(&capturePromotions, try sqr.Square.fromIndex(source));
//         var attackMap = map.pawnAttacks[side][source];
//         attackMap &= opponentPieces;
//         while (attackMap > 0) {
//             const target: u6 = @intCast(bit.LeastSignificantBit(attackMap));
//
//             bit.PopBit(&attackMap, try sqr.Square.fromIndex(@intCast(target)));
//
//             try list.append(Move{ .source = source, .target = target, .piece = piece, .promotion = .Q, .isCapture = true });
//             try list.append(Move{ .source = source, .target = target, .piece = piece, .promotion = .R, .isCapture = true });
//             try list.append(Move{ .source = source, .target = target, .piece = piece, .promotion = .B, .isCapture = true });
//             try list.append(Move{ .source = source, .target = target, .piece = piece, .promotion = .N, .isCapture = true });
//         }
//     }
//
//     while (captures > 0) {
//         const source: u6 = @intCast(bit.LeastSignificantBit(captures));
//         bit.PopBit(&captures, try sqr.Square.fromIndex(source));
//         var attackMap = map.pawnAttacks[side][source];
//         attackMap &= (opponentPieces | board.enPassantSquare);
//         while (attackMap > 0) {
//             const target: u6 = @intCast(bit.LeastSignificantBit(attackMap));
//
//             bit.PopBit(&attackMap, try sqr.Square.fromIndex(@intCast(target)));
//
//             if (target == epSquare) {
//                 try list.append(Move{ .source = source, .target = target, .piece = piece, .isCapture = true, .isEnPassant = true });
//             } else {
//                 try list.append(Move{ .source = source, .target = target, .piece = piece, .isCapture = true });
//             }
//         }
//     }
// }

pub fn KnightMoves(list: *std.ArrayList(Move), board: *brd.Board, side: u1, checkMask: u64, pinMask: u64) !void {
    const piece = if (side == 0) brd.Pieces.N else brd.Pieces.n;
    var knights = if (side == 0) board.wKnights else board.bKnights;
    const pieces = if (side == 0) board.wPieces() else board.bPieces();
    const enemyPieces = if (side == 0) board.bPieces() else board.wPieces();
    const kingBoard = if (side == 0) board.wKing else board.bKing;
    const kingSquare: u6 = @intCast(bit.LeastSignificantBit(kingBoard));
    while (knights > 0) {
        const source: u6 = @intCast(bit.LeastSignificantBit(knights));
        bit.PopBit(&knights, try sqr.Square.fromIndex(source));
        var targets = map.knightAttacks[source] & ~pieces;
        while (targets > 0) {
            const target: u6 = @intCast(bit.LeastSignificantBit(targets));
            bit.PopBit(&targets, try sqr.Square.fromIndex(target));
            const sourceBoard = @as(u64, 1) << source;
            const targetBoard = @as(u64, 1) << target;

            if (checkMask > 0) {
                const blockerChecker = (checkMask & targetBoard) > 0;

                if (!blockerChecker) {
                    continue;
                }
            }

            if ((pinMask & sourceBoard) > 0) {
                var boardCopy = board.*;
                if (side == 0) {
                    bit.PopBit(&boardCopy.wKnights, try sqr.Square.fromIndex(source));
                    bit.SetBit(&boardCopy.wKnights, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.bPawns, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.bKnights, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.bBishops, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.bRooks, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.bQueens, try sqr.Square.fromIndex(target));
                } else {
                    bit.PopBit(&boardCopy.bKnights, try sqr.Square.fromIndex(source));
                    bit.SetBit(&boardCopy.bKnights, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.wPawns, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.wKnights, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.wBishops, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.wRooks, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.wQueens, try sqr.Square.fromIndex(target));
                }

                if (boardCopy.isSquareAttacked(kingSquare, side) > 0) continue;
            }

            if (targetBoard & enemyPieces > 0) {
                try list.append(Move{ .source = source, .target = target, .piece = piece, .isCapture = true });
            } else {
                try list.append(Move{ .source = source, .target = target, .piece = piece });
            }
        }
    }
}

pub fn BishopMoves(list: *std.ArrayList(Move), board: *brd.Board, side: u1, checkMask: u64, pinMask: u64) !void {
    const piece = if (side == 0) brd.Pieces.B else brd.Pieces.b;
    var bishops = if (side == 0) board.wBishops else board.bBishops;
    const pieces = if (side == 0) board.wPieces() else board.bPieces();
    const enemyPieces = if (side == 0) board.bPieces() else board.wPieces();
    const kingBoard = if (side == 0) board.wKing else board.bKing;
    const kingSquare: u6 = @intCast(bit.LeastSignificantBit(kingBoard));
    while (bishops > 0) {
        const source: u6 = @intCast(bit.LeastSignificantBit(bishops));
        bit.PopBit(&bishops, try sqr.Square.fromIndex(source));
        var targets = map.GetBishopAttacks(source, board.allPieces()) & ~pieces;
        while (targets > 0) {
            const target: u6 = @intCast(bit.LeastSignificantBit(targets));
            const targetSquare = @as(u64, 1) << target;
            bit.PopBit(&targets, try sqr.Square.fromIndex(target));

            const sourceBoard = @as(u64, 1) << source;
            const targetBoard = @as(u64, 1) << target;

            if (checkMask > 0) {
                const blockerChecker = (checkMask & targetBoard) > 0;

                if (!blockerChecker) {
                    continue;
                }
            }

            if ((pinMask & sourceBoard) > 0) {
                var boardCopy = board.*;
                if (side == 0) {
                    bit.PopBit(&boardCopy.wBishops, try sqr.Square.fromIndex(source));
                    bit.SetBit(&boardCopy.wBishops, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.bPawns, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.bKnights, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.bBishops, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.bRooks, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.bQueens, try sqr.Square.fromIndex(target));
                } else {
                    bit.PopBit(&boardCopy.bBishops, try sqr.Square.fromIndex(source));
                    bit.SetBit(&boardCopy.bBishops, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.wPawns, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.wKnights, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.wBishops, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.wRooks, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.wQueens, try sqr.Square.fromIndex(target));
                }

                if (boardCopy.isSquareAttacked(kingSquare, side) > 0) continue;
            }

            if (targetSquare & enemyPieces > 0) {
                try list.append(Move{ .source = source, .target = target, .piece = piece, .isCapture = true });
            } else {
                try list.append(Move{ .source = source, .target = target, .piece = piece });
            }
        }
    }
}

pub fn RookMoves(list: *std.ArrayList(Move), board: *brd.Board, side: u1, checkMask: u64, pinMask: u64) !void {
    const piece = if (side == 0) brd.Pieces.R else brd.Pieces.r;
    var rooks = if (side == 0) board.wRooks else board.bRooks;
    const pieces = if (side == 0) board.wPieces() else board.bPieces();
    const enemyPieces = if (side == 0) board.bPieces() else board.wPieces();
    const kingBoard = if (side == 0) board.wKing else board.bKing;
    const kingSquare: u6 = @intCast(bit.LeastSignificantBit(kingBoard));

    while (rooks > 0) {
        const source: u6 = @intCast(bit.LeastSignificantBit(rooks));
        bit.PopBit(&rooks, try sqr.Square.fromIndex(source));
        var targets = map.GetRookAttacks(source, board.allPieces()) & ~pieces;
        while (targets > 0) {
            const target: u6 = @intCast(bit.LeastSignificantBit(targets));
            bit.PopBit(&targets, try sqr.Square.fromIndex(target));

            const sourceBoard = @as(u64, 1) << source;
            const targetBoard = @as(u64, 1) << target;

            if (checkMask > 0) {
                const blockerChecker = (checkMask & targetBoard) > 0;

                if (!blockerChecker) {
                    continue;
                }
            }

            if ((pinMask & sourceBoard) > 0) {
                var boardCopy = board.*;
                if (side == 0) {
                    bit.PopBit(&boardCopy.wRooks, try sqr.Square.fromIndex(source));
                    bit.SetBit(&boardCopy.wRooks, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.bPawns, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.bKnights, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.bBishops, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.bRooks, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.bQueens, try sqr.Square.fromIndex(target));
                } else {
                    bit.PopBit(&boardCopy.bRooks, try sqr.Square.fromIndex(source));
                    bit.SetBit(&boardCopy.bRooks, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.wPawns, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.wKnights, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.wBishops, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.wRooks, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.wQueens, try sqr.Square.fromIndex(target));
                }

                if (boardCopy.isSquareAttacked(kingSquare, side) > 0) continue;
            }

            if (targetBoard & enemyPieces > 0) {
                try list.append(Move{ .source = source, .target = target, .piece = piece, .isCapture = true });
            } else {
                try list.append(Move{ .source = source, .target = target, .piece = piece });
            }
        }
    }
}

pub fn QueenMoves(list: *std.ArrayList(Move), board: *brd.Board, side: u1, checkMask: u64, pinMask: u64) !void {
    const piece = if (side == 0) brd.Pieces.Q else brd.Pieces.q;
    var queens = if (side == 0) board.wQueens else board.bQueens;
    const pieces = if (side == 0) board.wPieces() else board.bPieces();
    const enemyPieces = if (side == 0) board.bPieces() else board.wPieces();
    const kingBoard = if (side == 0) board.wKing else board.bKing;
    const kingSquare: u6 = @intCast(bit.LeastSignificantBit(kingBoard));
    while (queens > 0) {
        const source: u6 = @intCast(bit.LeastSignificantBit(queens));
        bit.PopBit(&queens, try sqr.Square.fromIndex(source));
        const rookTargets = map.GetRookAttacks(source, board.allPieces()) & ~pieces;
        const bishopTargets = map.GetBishopAttacks(source, board.allPieces()) & ~pieces;
        var targets = rookTargets | bishopTargets;
        while (targets > 0) {
            const target: u6 = @intCast(bit.LeastSignificantBit(targets));
            bit.PopBit(&targets, try sqr.Square.fromIndex(target));

            const sourceBoard = @as(u64, 1) << source;
            const targetBoard = @as(u64, 1) << target;

            if (checkMask > 0) {
                const blockerChecker = (checkMask & targetBoard) > 0;

                if (!blockerChecker) {
                    continue;
                }
            }

            if ((pinMask & sourceBoard) > 0) {
                var boardCopy = board.*;
                if (side == 0) {
                    bit.PopBit(&boardCopy.wQueens, try sqr.Square.fromIndex(source));
                    bit.SetBit(&boardCopy.wQueens, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.bPawns, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.bKnights, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.bBishops, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.bRooks, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.bQueens, try sqr.Square.fromIndex(target));
                } else {
                    bit.PopBit(&boardCopy.bQueens, try sqr.Square.fromIndex(source));
                    bit.SetBit(&boardCopy.bQueens, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.wPawns, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.wKnights, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.wBishops, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.wRooks, try sqr.Square.fromIndex(target));
                    bit.PopBit(&boardCopy.wQueens, try sqr.Square.fromIndex(target));
                }

                if (boardCopy.isSquareAttacked(kingSquare, side) > 0) continue;
            }
            if (targetBoard & enemyPieces > 0) {
                try list.append(Move{ .source = source, .target = target, .piece = piece, .isCapture = true });
            } else {
                try list.append(Move{ .source = source, .target = target, .piece = piece });
            }
        }
    }
}

pub fn KingMoves(list: *std.ArrayList(Move), board: *brd.Board, side: u1) !void {
    const piece = if (side == 0) brd.Pieces.K else brd.Pieces.k;
    var king = if (side == 0) board.wKing else board.bKing;
    const pieces = if (side == 0) board.wPieces() else board.bPieces();
    const enemyPieces = if (side == 0) board.bPieces() else board.wPieces();
    while (king > 0) {
        const source: u6 = @intCast(bit.LeastSignificantBit(king));
        bit.PopBit(&king, try sqr.Square.fromIndex(source));
        var targets = try map.MaskKingAttacks(source) & ~pieces;
        while (targets > 0) {
            const target: u6 = @intCast(bit.LeastSignificantBit(targets));
            const targetSquare = @as(u64, 1) << target;
            bit.PopBit(&targets, try sqr.Square.fromIndex(target));

            var boardCopy = board.*;

            if (side == 0) {
                bit.PopBit(&boardCopy.wKing, try sqr.Square.fromIndex(source));
            } else {
                bit.PopBit(&boardCopy.bKing, try sqr.Square.fromIndex(source));
            }

            const attackers = boardCopy.isSquareAttacked(target, side);
            if (attackers > 0) continue;

            if (targetSquare & enemyPieces > 0) {
                try list.append(Move{ .source = source, .target = target, .piece = piece, .isCapture = true });
            } else {
                try list.append(Move{ .source = source, .target = target, .piece = piece });
            }
        }
    }
}

pub fn CastleMoves(list: *std.ArrayList(Move), board: *brd.Board, side: u1) !void {
    const piece = if (side == 0) brd.Pieces.K else brd.Pieces.k;
    const rooks = if (side == 0) board.wRooks else board.bRooks;
    const king = if (side == 0) board.wKing else board.bKing;
    const atHomeSquare: bool = (side == 1 and king == (1 << 4)) or (side == 0 and king == (1 << 60));
    if (!atHomeSquare) return;

    if (side == 0) {
        const kingSideRook: bool = (rooks & (map.FILE_H & map.RANK_1)) > 0;
        const queenSideRook: bool = (rooks & (map.FILE_A & map.RANK_1)) > 0;
        const b1 = sqr.Square.toIndex(.B1);
        const c1 = sqr.Square.toIndex(.C1);
        const d1 = sqr.Square.toIndex(.D1);
        const f1 = sqr.Square.toIndex(.F1);
        const g1 = sqr.Square.toIndex(.G1);
        if (board.castle & 1 > 0) {
            const kingSideCastleEmpty = bit.GetBit(board.allPieces(), f1) == 0 and bit.GetBit(board.allPieces(), g1) == 0;
            const kingSideCastleAttacked = board.isSquareAttacked(f1, 0) > 0 or board.isSquareAttacked(g1, 0) > 0;
            if (kingSideRook and kingSideCastleEmpty and !kingSideCastleAttacked) {
                try list.append(Move{
                    .source = 60,
                    .target = 62,
                    .piece = piece,
                    .castle = .WK,
                });
            }
        }
        if (board.castle & 2 > 0) {
            const queenSideCastleEmpty = bit.GetBit(board.allPieces(), b1) == 0 and bit.GetBit(board.allPieces(), c1) == 0 and bit.GetBit(board.allPieces(), d1) == 0;
            const queenSideCastleAttacked = board.isSquareAttacked(c1, 0) > 0 or board.isSquareAttacked(d1, 0) > 0;
            if (queenSideRook and queenSideCastleEmpty and !queenSideCastleAttacked) {
                try list.append(Move{
                    .source = 60,
                    .target = 58,
                    .piece = piece,
                    .castle = .WQ,
                });
            }
        }
    } else {
        const kingSideRook: bool = (rooks & (map.FILE_H & map.RANK_8)) > 0;
        const queenSideRook: bool = (rooks & (map.FILE_A & map.RANK_8)) > 0;
        const b8 = sqr.Square.toIndex(.B8);
        const c8 = sqr.Square.toIndex(.C8);
        const d8 = sqr.Square.toIndex(.D8);
        const f8 = sqr.Square.toIndex(.F8);
        const g8 = sqr.Square.toIndex(.G8);
        if (board.castle & 4 > 0) {
            const kingSideCastleEmpty = bit.GetBit(board.allPieces(), f8) == 0 and bit.GetBit(board.allPieces(), g8) == 0;
            const kingSideCastleAttacked = board.isSquareAttacked(f8, 1) > 0 or board.isSquareAttacked(g8, 1) > 0;
            if (kingSideRook and kingSideCastleEmpty and !kingSideCastleAttacked) {
                try list.append(Move{ .source = 4, .target = 6, .piece = piece, .castle = .BK });
            }
        }
        if (board.castle & 8 > 0) {
            const queenSideCastleEmpty = bit.GetBit(board.allPieces(), b8) == 0 and bit.GetBit(board.allPieces(), c8) == 0 and bit.GetBit(board.allPieces(), d8) == 0;
            const queenSideCastleAttacked = board.isSquareAttacked(c8, 1) > 0 or board.isSquareAttacked(d8, 1) > 0;
            if (queenSideRook and queenSideCastleEmpty and !queenSideCastleAttacked) {
                try list.append(Move{ .source = 4, .target = 2, .piece = piece, .castle = .BQ });
            }
        }
    }
}

pub const Move = struct {
    source: u6,
    target: u6,
    piece: brd.Pieces,
    promotion: Promotion = .X,
    isCapture: bool = false,
    isCheck: bool = false,
    isDoublePush: bool = false,
    isEnPassant: bool = false,
    castle: brd.Castle = .N,

    pub fn isPromotion(self: *Move) bool {
        return self.promotion != .X;
    }

    pub fn isCastle(self: *Move) bool {
        return self.castle != .N;
    }
    pub fn Convert(self: *Move) u24 {
        return @as(u24, self.source) |
            (@as(u24, self.target) << 6) |
            (@as(u24, @intFromEnum(self.piece)) << 12) |
            (@as(u24, @intFromEnum(self.promotion)) << 16) |
            (@as(u24, @intFromBool(self.isCapture)) << 20) |
            (@as(u24, @intFromBool(self.isDoublePush)) << 21) |
            (@as(u24, @intFromBool(self.isEnPassant)) << 22) |
            (@as(u24, @intFromEnum(self.castle)) << 23);
    }
};

pub fn fromU24(encoded: u24) Move {
    const source: u6 = @intCast(encoded & 0x3F);
    const target: u6 = @intCast((encoded >> 6) & 0x3F);
    const piece: brd.Pieces = @enumFromInt((encoded >> 12) & 0xF);
    const promotion: Promotion = @enumFromInt((encoded >> 16) & 0x7);
    const isCapture: bool = (encoded & (1 << 20)) != 0;
    const isDoublePush: bool = (encoded & (1 << 21)) != 0;
    const isEnPassant: bool = (encoded & (1 << 22)) != 0;
    const castle: brd.Castle = @enumFromInt((encoded >> 23) & 0x3);

    return Move{
        .source = source,
        .target = target,
        .piece = piece,
        .promotion = promotion,
        .isCapture = isCapture,
        .isDoublePush = isDoublePush,
        .isEnPassant = isEnPassant,
        .castle = castle,
    };
}
pub const Promotion = enum(u3) { X = 0, Q = 1, R = 2, B = 3, N = 4 };

pub fn MakeMove(move: Move, board: *brd.Board, side: u1) bool {
    const source = if (side == 0) board.GetWhitePieceBitBoard(move.piece) else board.GetBlackPieceBitBoard(move.piece);
    const sourceSquare = try sqr.Square.fromIndex(move.source);
    const epSquare = bit.LeastSignificantBit(board.enPassantSquare);
    bit.PopBit(&board.enPassantSquare, try sqr.Square.fromIndex(@truncate(epSquare)));
    bit.PopBit(source, try sqr.Square.fromIndex(move.source));
    if (move.promotion == .X) {
        bit.SetBit(source, try sqr.Square.fromIndex(move.target));
    }

    if (board.castle > 0 and move.castle == .N) {
        if (side == 0) {
            switch (move.piece) {
                brd.Pieces.K => {
                    if (board.castle & 1 > 0) board.castle ^= 1;
                    if (board.castle & 2 > 0) board.castle ^= 2;
                },
                brd.Pieces.R => {
                    if (sourceSquare == .A1) {
                        if (board.castle & 2 > 0) board.castle ^= 2;
                    } else if (sourceSquare == .H1) {
                        if (board.castle & 1 > 0) board.castle ^= 1;
                    }
                },
                else => {},
            }
        } else {
            switch (move.piece) {
                brd.Pieces.k => {
                    if (board.castle & 4 > 0) board.castle ^= 4;
                    if (board.castle & 8 > 0) board.castle ^= 8;
                },
                brd.Pieces.r => {
                    if (sourceSquare == .A8) {
                        if (board.castle & 8 > 0) board.castle ^= 8;
                        board.castle ^= 8;
                    } else if (sourceSquare == .H8) {
                        if (board.castle & 4 > 0) board.castle ^= 4;
                    }
                },
                else => {},
            }
        }
    }
    if (move.castle != .N) {
        switch (move.castle) {
            brd.Castle.WK => {
                if ((board.castle & 1) > 0) {
                    bit.PopBit(&board.wRooks, .H1);
                    bit.SetBit(&board.wRooks, .F1);
                    board.castle ^= 1;
                    board.castle ^= 2;
                } else {
                    @panic("Attempted to king side castle.");
                }
            },
            brd.Castle.WQ => {
                if ((board.castle & 2) > 0) {
                    bit.PopBit(&board.wRooks, .A1);
                    bit.SetBit(&board.wRooks, .D1);
                    board.castle ^= 1;
                    board.castle ^= 2;
                } else {
                    @panic("Attempted to Queen side castle.");
                }
            },
            brd.Castle.BK => {
                if ((board.castle & 4) > 0) {
                    bit.PopBit(&board.bRooks, .H8);
                    bit.SetBit(&board.bRooks, .F8);
                    board.castle ^= 4;
                    board.castle ^= 8;
                } else {
                    @panic("Attempted to king side castle");
                }
            },
            brd.Castle.BQ => {
                if ((board.castle & 8) > 0) {
                    bit.PopBit(&board.bRooks, .A8);
                    bit.SetBit(&board.bRooks, .D8);
                    board.castle ^= 4;
                    board.castle ^= 8;
                } else {
                    @panic("Attempted to queenside castle");
                }
            },
            else => @panic("Invalid Castle"),
        }
    }

    if (move.isDoublePush) {
        if (side == 0) {
            bit.SetBit(&board.enPassantSquare, try sqr.Square.fromIndex(move.target + 8));
        } else {
            bit.SetBit(&board.enPassantSquare, try sqr.Square.fromIndex(move.target - 8));
        }
    } else {
        if (move.isCapture) {
            if (side == 0) {
                if (move.isEnPassant) {
                    bit.PopBit(&board.bPawns, try sqr.Square.fromIndex(move.target + 8));
                } else {
                    bit.PopBit(&board.bPawns, try sqr.Square.fromIndex(move.target));
                    bit.PopBit(&board.bKnights, try sqr.Square.fromIndex(move.target));
                    bit.PopBit(&board.bBishops, try sqr.Square.fromIndex(move.target));
                    bit.PopBit(&board.bRooks, try sqr.Square.fromIndex(move.target));
                    bit.PopBit(&board.bQueens, try sqr.Square.fromIndex(move.target));
                    bit.PopBit(&board.bKing, try sqr.Square.fromIndex(move.target));
                }
            } else {
                if (move.isEnPassant) {
                    bit.PopBit(&board.wPawns, try sqr.Square.fromIndex(move.target - 8));
                } else {
                    bit.PopBit(&board.wPawns, try sqr.Square.fromIndex(move.target));
                    bit.PopBit(&board.wKnights, try sqr.Square.fromIndex(move.target));
                    bit.PopBit(&board.wBishops, try sqr.Square.fromIndex(move.target));
                    bit.PopBit(&board.wRooks, try sqr.Square.fromIndex(move.target));
                    bit.PopBit(&board.wQueens, try sqr.Square.fromIndex(move.target));
                    bit.PopBit(&board.wKing, try sqr.Square.fromIndex(move.target));
                }
            }
        }

        if (move.promotion != .X) {
            if (side == 0) {
                switch (move.promotion) {
                    Promotion.Q => {
                        bit.SetBit(&board.wQueens, try sqr.Square.fromIndex(move.target));
                    },
                    Promotion.N => {
                        bit.SetBit(&board.wKnights, try sqr.Square.fromIndex(move.target));
                    },
                    Promotion.B => {
                        bit.SetBit(&board.wBishops, try sqr.Square.fromIndex(move.target));
                    },
                    Promotion.R => {
                        bit.SetBit(&board.wRooks, try sqr.Square.fromIndex(move.target));
                    },
                    else => @panic("Invalid promotion"),
                }
            } else {
                switch (move.promotion) {
                    Promotion.Q => {
                        bit.SetBit(&board.bQueens, try sqr.Square.fromIndex(move.target));
                    },
                    Promotion.N => {
                        bit.SetBit(&board.bKnights, try sqr.Square.fromIndex(move.target));
                    },
                    Promotion.B => {
                        bit.SetBit(&board.bBishops, try sqr.Square.fromIndex(move.target));
                    },
                    Promotion.R => {
                        bit.SetBit(&board.bRooks, try sqr.Square.fromIndex(move.target));
                    },
                    else => @panic("Invalid promotion"),
                }
            }
        }
    }
    const kingSquare = if (side == 0) bit.LeastSignificantBit(board.wKing) else bit.LeastSignificantBit(board.bKing);
    if (board.isSquareAttacked(@intCast(kingSquare), side) > 0) {
        return false;
    }

    return true;
}
