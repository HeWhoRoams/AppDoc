// Demo C# Models for AppDoc demonstration
// This file contains sample entity models with varying documentation levels

using System;
using System.Collections.Generic;

/// <summary>
/// Represents a user in the system.
/// This class is fully documented with XML comments.
/// </summary>
public class User
{
    /// <summary>
    /// Gets or sets the unique identifier for the user.
    /// </summary>
    public int Id { get; set; }

    /// <summary>
    /// Gets or sets the user's full name.
    /// </summary>
    public string Name { get; set; }

    /// <summary>
    /// Gets or sets the user's email address.
    /// </summary>
    public string Email { get; set; }

    /// <summary>
    /// Gets or sets the date when the user was created.
    /// </summary>
    public DateTime CreatedAt { get; set; }

    /// <summary>
    /// Initializes a new instance of the User class.
    /// </summary>
    public User()
    {
        CreatedAt = DateTime.UtcNow;
    }

    /// <summary>
    /// Initializes a new instance of the User class with specified values.
    /// </summary>
    /// <param name="id">The user ID.</param>
    /// <param name="name">The user's name.</param>
    /// <param name="email">The user's email.</param>
    public User(int id, string name, string email)
    {
        Id = id;
        Name = name;
        Email = email;
        CreatedAt = DateTime.UtcNow;
    }
}

// This class lacks documentation - shows up as undocumented in reports
public class Product
{
    public int Id { get; set; }
    public string Name { get; set; }
    public decimal Price { get; set; }
    public string Category { get; set; }

    public Product() { }

    // Undocumented method
    public decimal CalculateDiscount(decimal percentage)
    {
        return Price * (1 - percentage / 100);
    }
}

/// <summary>
/// Service class for user operations.
/// Contains both documented and undocumented methods.
/// </summary>
public class UserService
{
    private List<User> users = new List<User>();

    /// <summary>
    /// Retrieves a user by their ID.
    /// </summary>
    /// <param name="id">The user ID to search for.</param>
    /// <returns>The user if found, null otherwise.</returns>
    public User GetUserById(int id)
    {
        return users.Find(u => u.Id == id);
    }

    // This method is undocumented
    public List<User> GetAllUsers()
    {
        return users;
    }

    /// <summary>
    /// Adds a new user to the system.
    /// </summary>
    /// <param name="user">The user to add.</param>
    /// <returns>True if added successfully, false if user already exists.</returns>
    public bool AddUser(User user)
    {
        if (users.Any(u => u.Id == user.Id))
            return false;

        users.Add(user);
        return true;
    }
}
