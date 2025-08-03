import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Game2048 extends StatefulWidget {
  const Game2048({super.key});

  @override
  State<Game2048> createState() => _Game2048State();
}

class _Game2048State extends State<Game2048> {
  late List<List<int>> board;
  int score = 0;
  int highScore = 0;
  bool gameOver = false;
  final int boardSize = 4;
  final Random _random = Random();
  final FocusNode _focusNode = FocusNode();

  Timer? _timer;
  int _secondsElapsed = 0;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    _loadHighScore();
    _startGame();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      highScore = prefs.getInt('highScore') ?? 0;
    });
  }

  Future<void> _saveHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    if (score > highScore) {
      await prefs.setInt('highScore', score);
      setState(() {
        highScore = score;
      });
    }
  }

  void _startTimer() {
    _secondsElapsed = 0;
    _timer?.cancel(); // Cancel any existing timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _secondsElapsed++;
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  void _startGame() {
    setState(() {
      board = List.generate(boardSize, (_) => List.generate(boardSize, (_) => 0));
      score = 0;
      gameOver = false;
      _addRandomTile();
      _addRandomTile();
      _startTimer();
    });
  }

  void _addRandomTile() {
    List<Point> emptyCells = [];
    for (int i = 0; i < boardSize; i++) {
      for (int j = 0; j < boardSize; j++) {
        if (board[i][j] == 0) {
          emptyCells.add(Point(i, j));
        }
      }
    }

    if (emptyCells.isNotEmpty) {
      Point randomCell = emptyCells[_random.nextInt(emptyCells.length)];
      board[randomCell.x][randomCell.y] = _random.nextDouble() < 0.9 ? 2 : 4;
    } else {
      _checkGameOver();
    }
  }

  bool _move(Direction direction) {
    bool moved = false;
    int newScore = 0;

    List<List<int>> newBoard = List.generate(boardSize, (_) => List.generate(boardSize, (_) => 0));

    // Create a deep copy of the board to compare later
    List<List<int>> oldBoard = board.map((row) => List<int>.from(row)).toList();

    for (int i = 0; i < boardSize; i++) {
      List<int> rowOrCol = [];
      if (direction == Direction.left || direction == Direction.right) {
        rowOrCol = List.from(board[i]);
      } else {
        for (int j = 0; j < boardSize; j++) {
          rowOrCol.add(board[j][i]);
        }
      }

      List<int> newRowOrCol = _slideAndMerge(rowOrCol, direction, (s) => newScore += s);

      if (direction == Direction.left || direction == Direction.right) {
        for (int j = 0; j < boardSize; j++) {
          newBoard[i][j] = newRowOrCol[j];
        }
      } else {
        for (int j = 0; j < boardSize; j++) {
          newBoard[j][i] = newRowOrCol[j];
        }
      }
    }

    // Check if any tile actually moved by comparing oldBoard with newBoard
    for (int i = 0; i < boardSize; i++) {
      for (int j = 0; j < boardSize; j++) {
        if (oldBoard[i][j] != newBoard[i][j]) {
          moved = true;
          break;
        }
      }
      if (moved) break;
    }

    if (moved) {
      setState(() {
        board = newBoard;
        score += newScore;
        _addRandomTile();
        _checkGameOver();
      });
    }
    return moved;
  }

  List<int> _slideAndMerge(List<int> line, Direction direction, Function(int) onMerge) {
    List<int> newLine = line.where((tile) => tile != 0).toList();

    if (direction == Direction.right || direction == Direction.down) {
      newLine = newLine.reversed.toList();
    }

    for (int i = 0; i < newLine.length - 1; i++) {
      if (newLine[i] == newLine[i + 1]) {
        newLine[i] *= 2;
        onMerge(newLine[i]);
        newLine.removeAt(i + 1);
        newLine.add(0); // Add a zero to the end after merging
      }
    }

    while (newLine.length < boardSize) {
      newLine.add(0);
    }

    if (direction == Direction.right || direction == Direction.down) {
      newLine = newLine.reversed.toList();
    }

    return newLine;
  }

  void _checkGameOver() {
    if (_getEmptyCells().isEmpty) {
      bool canMove = false;
      for (int i = 0; i < boardSize; i++) {
        for (int j = 0; j < boardSize; j++) {
          if (j < boardSize - 1 && board[i][j] == board[i][j + 1]) {
            canMove = true;
            break;
          }
          if (i < boardSize - 1 && board[i][j] == board[i + 1][j]) {
            canMove = true;
            break;
          }
        }
        if (canMove) break;
      }
      if (!canMove) {
        setState(() {
          gameOver = true;
        });
        _stopTimer();
        _saveHighScore();
      }
    }
  }

  List<Point> _getEmptyCells() {
    List<Point> emptyCells = [];
    for (int i = 0; i < boardSize; i++) {
      for (int j = 0; j < boardSize; j++) {
        if (board[i][j] == 0) {
          emptyCells.add(Point(i, j));
        }
      }
    }
    return emptyCells;
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (gameOver) return;

      bool moved = false;
      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowLeft:
          moved = _move(Direction.left);
          break;
        case LogicalKeyboardKey.arrowRight:
          moved = _move(Direction.right);
          break;
        case LogicalKeyboardKey.arrowUp:
          moved = _move(Direction.up);
          break;
        case LogicalKeyboardKey.arrowDown:
          moved = _move(Direction.down);
          break;
      }
    }
  }

  Color _getTileColor(int value) {
    switch (value) {
      case 0:
        return Colors.grey[200]!;
      case 2:
        return Colors.grey[300]!;
      case 4:
        return Colors.grey[400]!;
      case 8:
        return Colors.orange[100]!;
      case 16:
        return Colors.orange[200]!;
      case 32:
        return Colors.orange[300]!;
      case 64:
        return Colors.orange[400]!;
      case 128:
        return Colors.yellow[300]!;
      case 256:
        return Colors.yellow[400]!;
      case 512:
        return Colors.yellow[500]!;
      case 1024:
        return Colors.red[300]!;
      case 2048:
        return Colors.red[400]!;
      default:
        return Colors.black;
    }
  }

  Color _getTileTextColor(int value) {
    if (value <= 4) {
      return Colors.grey[800]!;
    }
    return Colors.white;
  }

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: _handleKeyEvent,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('2048 Game'),
          actions: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: Text(
                  'Score: $score',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: Text(
                  'High Score: $highScore',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: Text(
                  'Time: ${_formatTime(_secondsElapsed)}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _startGame,
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 300,
                height: 300,
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 8.0,
                    mainAxisSpacing: 8.0,
                  ),
                  itemCount: boardSize * boardSize,
                  itemBuilder: (context, index) {
                    int row = index ~/ boardSize;
                    int col = index % boardSize;
                    int value = board[row][col];
                    return Container(
                      decoration: BoxDecoration(
                        color: _getTileColor(value),
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: Center(
                        child: Text(
                          value == 0 ? '' : '$value',
                          style: TextStyle(
                            fontSize: value < 100 ? 32 : (value < 1000 ? 24 : 18),
                            fontWeight: FontWeight.bold,
                            color: _getTileTextColor(value),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (gameOver)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'Game Over!',
                        style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.red),
                      ),
                      ElevatedButton(
                        onPressed: _startGame,
                        child: const Text('New Game'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum Direction { left, right, up, down }

class Point {
  final int x;
  final int y;
  Point(this.x, this.y);
}