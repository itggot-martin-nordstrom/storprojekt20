# Sets database to database.db
#
# @return SQLite3 database
def set_db()
    db = SQLite3::Database.new('database/database.db')
    db.results_as_hash = true

    return db
end

# Gets a user's username from their id
#
# @param [Integer] user_id A user's id
#
# @return [String] The user's username
def username_from_id(user_id)
    db = set_db()    
    name = db.execute('SELECT username FROM users WHERE id = (?)', user_id)
    return name
end

# Gets a user's id from their username
#
# @param [String] username A user's username
#
# @return [Integer] name The user's id
def id_from_username(username)
    db = set_db()    
    id = db.execute('SELECT id FROM users WHERE username = (?)', username)
    return id
end

# Sees if user exists by username
#
# @param [String] username A user's username
#
# @return [Boolean] If user exists or not
def user_exists(username)
    db = set_db()    
    boolean = true

    result = db.execute("SELECT id FROM users WHERE username=?", username)
    if result.empty?
        boolean = false
    end

    return boolean
end

# Checks if user has completed their profile by having a username
#
# @param [String] username A user's username
#
# @return [Hash]
#   * :completed [Boolean] whether the profile is complete
#   * :id [Integer] the user's id
def completed_profile(username)
    db = set_db()
    boolean = true

    result = db.execute("SELECT id,name FROM users WHERE username=?", username)
    if result.first['name'].nil?
        boolean = false
        id = result.first['id']
    else
        id = nil
    end

    return {completed: boolean, id: id}
end

# Completes a user's profile
#
# @param [String] name The user's nickname
# @param [String] class_name The name of the user's class
# @param [Integer] id The user's id
def update_profile(name, class_name, id)
    db.execute("UPDATE users SET name=?, class_name=? WHERE id=?", [name, class_name, id])
end

# Checks if nickname is taken in their class
#
# @param [String] name The user's nickname
# @param [String] class_name The name of the user's class
#
# @return [Boolean] If nickname is taken or not 
def name_taken(name, class_name)
    db = set_db()

    boolean = false
    result = db.execute("SELECT name FROM users WHERE name = (?) AND class_name = (?)", [name, class_name])

    if result.empty? == false
        boolean = true
    end

    return boolean
end

# Creates new user if password is allowed, matches and user does not already exist
#
# @param [String] username The user's username
# @param [String] password The user's password
# @param [String] confirm Check to see if passwords match
#
# @return [Hash]
#   * :current_user [Integer] The user's id
#   * :error [false] if there were no errors
# @return [Hash] if some error was found
#   * :current_user [nil]
#   * :error [String] if an error was found
def signup(username, password, confirm)
    db = set_db()
    boolean = false

    existor = user_exists(username)
    if existor != true
        
        if password == confirm
            
            if password.length >= 4
                password_digest = BCrypt::Password.create(password)
                db.execute('INSERT INTO users(username, password_digest) VALUES (?,?)', [username, password_digest])
                current_user = db.execute('SELECT id FROM users WHERE username=?', username).first['id']
                errormsg = false
            else
                errormsg = "Password too short"
            end
        else
            errormsg = "Passwords don't match"
        end
    else
        errormsg = "User already exists"
    end

    return {current_user: current_user, error: errormsg}
end

# Logs the user in if credentials are correct
#
# @param [String] username The user's username
# @param [String] password The user's password
#
# @return [Hash]
#   * :current_user [Integer] The user's id
#   * :error [false] if there were no errors
#   * :admin [Boolean] if user is an admin or not
def login_snake(username, password)
    db = set_db()
    result = db.execute("SELECT id, name, password_digest, class_name FROM users WHERE username = ?", username)
    admin = false

    if result.empty?    
        errormsg = "Invalid credentials"
    elsif result.first['name'].nil?
        errormsg = "Not completed profile"
    else
        password_digest = result.first["password_digest"]
        if BCrypt::Password.new(password_digest) == password
            current_user = result.first["id"]
            errormsg = false

            if result.first['class_name'] == nil
                admin = true
            end
        else
            errormsg = "Incorrect password"
        end
    end

    return {current_user: current_user, error: errormsg, admin: admin}
end

# Gets other user's in the current user's class
#
# @param [Integer] current_user The user's id
#
# @return [Array] containing the data of all matching users
def fetch_classmates(current_user)
    db = set_db()
    classmates = db.execute(
   'SELECT id, name 
    FROM users
    WHERE class_name = 
        (SELECT class_name
        FROM users
        WHERE id = (?))
    AND id IS NOT (?)', [current_user, current_user])
    return classmates                                
end

# Removes a voting option from a user
#
# @param [Integer] option_id The option's id
def remove_option(option_id)
    db = set_db()

    db.execute('DELETE FROM options WHERE option_id=?', option_id)
    db.execute('DELETE FROM votes WHERE option_id=?', option_id)
end

# Gets all options for all users in a specified order
#
# @param [String] order The order the results will be sorted by
#
# @return [Array] containing all options ordered by the parameter
def fetch_options(order)
    db = set_db()

    options = db.execute("SELECT option_id, name, class_name, content, no_of_votes FROM users LEFT JOIN options ON users.id = options.for_user WHERE option_id IS NOT NULL ORDER BY #{order}")
    
    return options
    
end

# Gets all options for a specific user if user and current user are classmates
#
# @param [String] user_id The current user's id
# @param [String] target_id The id of the user that is being voted on
#
# @return [Hash]
#   * :options [Array] All options that can be voted on
#   * :error [false] if there were no errors
#   * :users_vote [String/nil] Content of the vote the user has on the target. Is nil if no vote has been cast
def fetch_voting_page(user_id, target_id)
    db = set_db()
    
    errormsg = false

    # safety för användare som inte är i samma klass
    user_classname = db.execute('SELECT class_name FROM users WHERE id=?', user_id)
    target_classname = db.execute('SELECT class_name FROM users WHERE id=?', target_id)

    if user_classname != target_classname
        errormsg = "Oops, you can't vote for that user!"
    else
        options = db.execute('SELECT option_id, content, no_of_votes FROM options WHERE for_user = ? ORDER BY no_of_votes DESC', target)
        users_vote = db.execute("SELECT content FROM options WHERE option_id = (SELECT option_id FROM votes WHERE voter_id = ? AND target_id = ?)", [user, target])

        if users_vote != []
            users_vote = users_vote.first['content']
        end
    end

    return {options: options, error: errormsg, users_vote: users_vote}
end

# Creates a new option for a specified user
#
# @param [String] content The content of the option
# @param [String] target_id The id of the user that is being voted on
#
# @return [false]
# @return [String] if an error was found
def new_option(content, target_id)
    db = set_db()
    
    errormsg = false

    # safety för dubletter
    exister = db.execute('SELECT option_id FROM options WHERE content=? AND for_user=?', [content, target_id])

    if exister.empty?
        db.execute('INSERT INTO options(content, for_user, no_of_votes) VALUES (?,?, 0)', [content, target_id])
    else
        errormsg = "Option already exists, go vote for it!"
    end

    return errormsg
end

# Updates a user's vote on a target
#
# @param [String] user_id The current user's id
# @param [String] target_id The id of the user that is being voted on
# @param [String] option_id The option's id
def vote(user_id, target_id, option_id)
    db = set_db()

    exister = db.execute('SELECT option_id FROM votes WHERE voter_id=? AND  target_id=?', [user_id, target_id])
    
    if exister.length != 0
        old_id = exister[0]['option_id']
        no_of_votes = db.execute('SELECT no_of_votes FROM options WHERE option_id=?', old_id)[0]['no_of_votes']
        
        db.execute('DELETE FROM votes WHERE voter_id=? AND  target_id=?', [user_id, target_id])
        # removes one vote from option
        db.execute('UPDATE options SET no_of_votes=? WHERE option_id=?', [no_of_votes-1, old_id])
    end
    db.execute('INSERT INTO votes(voter_id, target_id, option_id) VALUES (?,?,?)', [user_id, target_id, option_id])

    # counts votes_for
    number = db.execute('SELECT option_id FROM votes WHERE option_id=?', option_id).length
    db.execute('UPDATE options SET no_of_votes=? WHERE option_id=?', [number, option_id])
end