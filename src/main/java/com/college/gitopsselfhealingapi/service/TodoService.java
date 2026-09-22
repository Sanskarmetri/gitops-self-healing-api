package com.college.gitopsselfhealingapi.service;

import com.college.gitopsselfhealingapi.model.Todo;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicLong;

@Service
public class TodoService {

    private final List<Todo> todos = new ArrayList<>();
    private final AtomicLong idCounter = new AtomicLong(1);

    public List<Todo> getAllTodos() {
        return new ArrayList<>(todos);
    }

    public Todo addTodo(Todo todo) {
        todo.setId(idCounter.getAndIncrement());
        todos.add(todo);
        return todo;
    }
}
