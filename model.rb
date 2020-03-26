# before do
def set_db()
    db = SQLite3::Database.new('database/database.db')
    db.results_as_hash = true

    return db
end

def username_from_id(user_id)
    db = set_db()    
    name = db.execute('SELECT username FROM users WHERE id = (?)', user_id)
    return name
end
def id_from_username(username)
    db = set_db()    
    id = db.execute('SELECT id FROM users WHERE username = (?)', username)
    return id
end

def user_exists(username)
    db = set_db()    
    boolean = true

    result = db.execute("SELECT id FROM users WHERE username=?", username)
    if result.empty?
        boolean = false
    end

    return boolean
end

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

    return boolean, id
end

def name_taken(name, class_name)
    db = set_db()

    boolean = false
    result = db.execute("SELECT name FROM users WHERE name = (?) AND class_name = (?)", [name, class_name])

    if result.empty? == false
        boolean = true
    end

    return boolean
end

def signup_passwords(username, password, confirm)
    db = set_db()
    boolean = false

    existor = user_exists(username)
    if existor != true
        if password == confirm
            if password.length >= 4
                password_digest = BCrypt::Password.create(password)
                db.execute('INSERT INTO users(username, password_digest) VALUES (?,?)', [username, password_digest])
                current_user = db.execute('SELECT id FROM users WHERE username=?', username).first['id']
                # p "hej" + current_user.to_s
                errormsg = nil
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

def login_snake(username, password)
    db = set_db()
    result = db.execute("SELECT id, name, password_digest, class_name FROM users WHERE username = ?", username)
    admin = false

    # p result

    if result.empty?    
        errormsg = "Invalid credentials"
    elsif result.first['name'].nil?
        errormsg = "Not completed profile"
    else
        password_digest = result.first["password_digest"]
        if BCrypt::Password.new(password_digest) == password
            current_user = result.first["id"]
            errormsg = nil

            if result.first['class_name'] == nil
                admin = true
            end
        else
            errormsg = "Incorrect password"
        end
    end

    return {current_user: current_user, error: errormsg, admin: admin}
end

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

def remove_option(option_id)
    db = set_db()

    db.execute('DELETE FROM options WHERE option_id=?', option_id)
    db.execute('DELETE FROM votes WHERE option_id=?', option_id)
end

def fetch_options(order)
    db = set_db()
    
    p order
    
    options = db.execute("SELECT option_id, name, class_name, content, no_of_votes FROM users LEFT JOIN options ON users.id = options.for_user WHERE option_id IS NOT NULL ORDER BY #{order}")
    
    return options
    
end

def fetch_voting_page(user, target)
    db = set_db()
    
    errormsg = nil

    # safety för användare som inte är i samma klass
    user_classname = db.execute('SELECT class_name FROM users WHERE id=?', user)
    target_classname = db.execute('SELECT class_name FROM users WHERE id=?', target)

    if user_classname != target_classname
        errormsg = "Oops, you can't vote for that user!"
    else
        options = db.execute('SELECT option_id, content, no_of_votes FROM options WHERE for_user = ? ORDER BY no_of_votes DESC', target)
        users_vote = db.execute("SELECT content FROM options WHERE option_id = (SELECT option_id FROM votes WHERE voter_id = ? AND target_id = ?)", [user, target])
        # p users_vote
        if users_vote != []
            users_vote = users_vote.first['content']
        end
    end

    return {options: options, error: errormsg, users_vote: users_vote}
end

def new_option(content, target)
    db = set_db()
    
    errormsg = nil

    # safety för dubletter
    exister = db.execute('SELECT option_id FROM options WHERE content=? AND for_user=?', [content, target])

    if exister.empty?
        db.execute('INSERT INTO options(content, for_user, no_of_votes) VALUES (?,?, 0)', [content, target])
        # redirect("/users/voting/#{option_for}")
    else
        errormsg = "Option already exists, go vote for it!"
    end

    return errormsg
end

def vote(user, target, option)
    db = set_db()

    exister = db.execute('SELECT option_id FROM votes WHERE voter_id=? AND  target_id=?', [user, target])
    
    if exister.length != 0
        old_id = exister[0]['option_id']
        no_of_votes = db.execute('SELECT no_of_votes FROM options WHERE option_id=?', old_id)[0]['no_of_votes']
        
        db.execute('DELETE FROM votes WHERE voter_id=? AND  target_id=?', [user, target])
        # removes one vote from option
        db.execute('UPDATE options SET no_of_votes=? WHERE option_id=?', [no_of_votes-1, old_id])
    end
    db.execute('INSERT INTO votes(voter_id, target_id, option_id) VALUES (?,?,?)', [user, target, option])


    # counts votes_for
    number = db.execute('SELECT option_id FROM votes WHERE option_id=?', option).length
    db.execute('UPDATE options SET no_of_votes=? WHERE option_id=?', [number, option])
end