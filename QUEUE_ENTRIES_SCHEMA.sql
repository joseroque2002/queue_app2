-- Queue Entries Table Schema
-- This script creates or updates the queue_entries table with all required columns, indexes, and constraints

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS trigger_update_priority ON public.queue_entries;

-- Create or replace the update_priority_status function
CREATE OR REPLACE FUNCTION update_priority_status()
RETURNS TRIGGER AS $$
BEGIN
    NEW.is_priority := (COALESCE(NEW.is_pwd, FALSE) OR COALESCE(NEW.is_senior, FALSE) OR COALESCE(NEW.is_pregnant, FALSE));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the queue_entries table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.queue_entries (
    id text NOT NULL,
    name text NOT NULL,
    ssu_id text NOT NULL,
    email text NOT NULL,
    phone_number text NOT NULL,
    department text NOT NULL,
    purpose text NOT NULL,
    timestamp timestamp with time zone NOT NULL DEFAULT now(),
    queue_number integer NOT NULL,
    status text NOT NULL DEFAULT 'waiting'::text,
    countdown_start timestamp with time zone NULL,
    countdown_duration integer NOT NULL DEFAULT 30,
    sms_opt_in boolean NOT NULL DEFAULT false,
    notified_top5 boolean NOT NULL DEFAULT false,
    last_notified_at timestamp with time zone NULL,
    is_pwd boolean NULL DEFAULT false,
    is_senior boolean NULL DEFAULT false,
    is_priority boolean NULL DEFAULT false,
    student_type character varying(50) NULL DEFAULT 'Student'::character varying,
    reference_number character varying(50) NULL,
    course character varying(20) NOT NULL,
    is_pregnant boolean NOT NULL DEFAULT false,
    CONSTRAINT queue_entries_pkey PRIMARY KEY (id),
    CONSTRAINT queue_entries_reference_number_key UNIQUE (reference_number),
    CONSTRAINT check_student_type CHECK (
        (student_type)::text = ANY (
            (ARRAY['Student'::character varying, 'Graduated'::character varying])::text[]
        )
    )
) TABLESPACE pg_default;

-- Add foreign key constraints if they don't exist
DO $$
BEGIN
    -- Add foreign key to departments table
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'fk_queue_entries_department'
    ) THEN
        ALTER TABLE public.queue_entries
        ADD CONSTRAINT fk_queue_entries_department 
        FOREIGN KEY (department) REFERENCES departments(code);
    END IF;

    -- Add foreign key to purposes table
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'fk_queue_entries_purpose'
    ) THEN
        ALTER TABLE public.queue_entries
        ADD CONSTRAINT fk_queue_entries_purpose 
        FOREIGN KEY (purpose) REFERENCES purposes(name);
    END IF;
END $$;

-- Add missing columns if table already exists
DO $$
BEGIN
    -- Add id column if it doesn't exist (for existing tables)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'queue_entries' AND column_name = 'id'
    ) THEN
        ALTER TABLE public.queue_entries ADD COLUMN id text;
        -- Generate IDs for existing rows
        UPDATE public.queue_entries SET id = gen_random_uuid()::text WHERE id IS NULL;
        ALTER TABLE public.queue_entries ALTER COLUMN id SET NOT NULL;
        -- Add primary key if it doesn't exist
        IF NOT EXISTS (
            SELECT 1 FROM pg_constraint WHERE conname = 'queue_entries_pkey'
        ) THEN
            ALTER TABLE public.queue_entries ADD CONSTRAINT queue_entries_pkey PRIMARY KEY (id);
        END IF;
    END IF;

    -- Add name column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'queue_entries' AND column_name = 'name'
    ) THEN
        ALTER TABLE public.queue_entries ADD COLUMN name text NOT NULL DEFAULT '';
    END IF;

    -- Add ssu_id column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'queue_entries' AND column_name = 'ssu_id'
    ) THEN
        ALTER TABLE public.queue_entries ADD COLUMN ssu_id text NOT NULL DEFAULT '';
    END IF;

    -- Add email column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'queue_entries' AND column_name = 'email'
    ) THEN
        ALTER TABLE public.queue_entries ADD COLUMN email text NOT NULL DEFAULT '';
    END IF;

    -- Add phone_number column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'queue_entries' AND column_name = 'phone_number'
    ) THEN
        ALTER TABLE public.queue_entries ADD COLUMN phone_number text NOT NULL DEFAULT '';
    END IF;

    -- Add department column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'queue_entries' AND column_name = 'department'
    ) THEN
        ALTER TABLE public.queue_entries ADD COLUMN department text NOT NULL DEFAULT 'CAS';
    END IF;

    -- Add purpose column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'queue_entries' AND column_name = 'purpose'
    ) THEN
        ALTER TABLE public.queue_entries ADD COLUMN purpose text NOT NULL DEFAULT 'General Inquiry';
    END IF;

    -- Add timestamp column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'queue_entries' AND column_name = 'timestamp'
    ) THEN
        ALTER TABLE public.queue_entries ADD COLUMN timestamp timestamp with time zone NOT NULL DEFAULT now();
    END IF;

    -- Add queue_number column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'queue_entries' AND column_name = 'queue_number'
    ) THEN
        ALTER TABLE public.queue_entries ADD COLUMN queue_number integer NOT NULL DEFAULT 1;
    END IF;

    -- Add status column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'queue_entries' AND column_name = 'status'
    ) THEN
        ALTER TABLE public.queue_entries ADD COLUMN status text NOT NULL DEFAULT 'waiting'::text;
    END IF;

    -- Add countdown_start column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'queue_entries' AND column_name = 'countdown_start'
    ) THEN
        ALTER TABLE public.queue_entries ADD COLUMN countdown_start timestamp with time zone NULL;
    END IF;

    -- Add countdown_duration column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'queue_entries' AND column_name = 'countdown_duration'
    ) THEN
        ALTER TABLE public.queue_entries ADD COLUMN countdown_duration integer NOT NULL DEFAULT 30;
    END IF;

    -- Add sms_opt_in column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'queue_entries' AND column_name = 'sms_opt_in'
    ) THEN
        ALTER TABLE public.queue_entries ADD COLUMN sms_opt_in boolean NOT NULL DEFAULT false;
    END IF;

    -- Add notified_top5 column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'queue_entries' AND column_name = 'notified_top5'
    ) THEN
        ALTER TABLE public.queue_entries ADD COLUMN notified_top5 boolean NOT NULL DEFAULT false;
    END IF;

    -- Add last_notified_at column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'queue_entries' AND column_name = 'last_notified_at'
    ) THEN
        ALTER TABLE public.queue_entries ADD COLUMN last_notified_at timestamp with time zone NULL;
    END IF;

    -- Add is_pwd column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'queue_entries' AND column_name = 'is_pwd'
    ) THEN
        ALTER TABLE public.queue_entries ADD COLUMN is_pwd boolean NULL DEFAULT false;
    END IF;

    -- Add is_senior column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'queue_entries' AND column_name = 'is_senior'
    ) THEN
        ALTER TABLE public.queue_entries ADD COLUMN is_senior boolean NULL DEFAULT false;
    END IF;

    -- Add is_priority column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'queue_entries' AND column_name = 'is_priority'
    ) THEN
        ALTER TABLE public.queue_entries ADD COLUMN is_priority boolean NULL DEFAULT false;
    END IF;

    -- Add student_type column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'queue_entries' AND column_name = 'student_type'
    ) THEN
        ALTER TABLE public.queue_entries ADD COLUMN student_type character varying(50) NULL DEFAULT 'Student'::character varying;
    END IF;

    -- Add reference_number column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'queue_entries' AND column_name = 'reference_number'
    ) THEN
        ALTER TABLE public.queue_entries ADD COLUMN reference_number character varying(50) NULL;
    END IF;

    -- Add course column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'queue_entries' AND column_name = 'course'
    ) THEN
        ALTER TABLE public.queue_entries ADD COLUMN course character varying(20) NOT NULL DEFAULT 'N/A';
    END IF;

    -- Add is_pregnant column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'queue_entries' AND column_name = 'is_pregnant'
    ) THEN
        ALTER TABLE public.queue_entries ADD COLUMN is_pregnant boolean NOT NULL DEFAULT false;
    END IF;

    -- Ensure course is NOT NULL
    UPDATE public.queue_entries SET course = 'N/A' WHERE course IS NULL;
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'queue_entries' AND column_name = 'course' AND is_nullable = 'YES'
    ) THEN
        ALTER TABLE public.queue_entries ALTER COLUMN course SET NOT NULL;
    END IF;

    -- Ensure is_pregnant is NOT NULL
    UPDATE public.queue_entries SET is_pregnant = false WHERE is_pregnant IS NULL;
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'queue_entries' AND column_name = 'is_pregnant' AND is_nullable = 'YES'
    ) THEN
        ALTER TABLE public.queue_entries ALTER COLUMN is_pregnant SET NOT NULL;
    END IF;
END $$;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_queue_entries_countdown_start 
    ON public.queue_entries USING btree (countdown_start) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_queue_dept_status_queue 
    ON public.queue_entries USING btree (department, status, queue_number) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_queue_dept_status_timestamp 
    ON public.queue_entries USING btree (department, status, timestamp DESC) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_queue_entries_department 
    ON public.queue_entries USING btree (department) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_queue_entries_status 
    ON public.queue_entries USING btree (status) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_queue_entries_queue_number 
    ON public.queue_entries USING btree (queue_number) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_queue_dept_queue_desc 
    ON public.queue_entries USING btree (department, queue_number DESC) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_queue_dept_status_waiting 
    ON public.queue_entries USING btree (department, status, queue_number) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_queue_entries_reference_number 
    ON public.queue_entries USING btree (reference_number) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_queue_entries_course 
    ON public.queue_entries USING btree (course) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_queue_entries_department_course 
    ON public.queue_entries USING btree (department, course) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_queue_entries_priority_display 
    ON public.queue_entries USING btree (department, is_priority DESC, queue_number, status) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_queue_entries_is_pregnant 
    ON public.queue_entries USING btree (is_pregnant) TABLESPACE pg_default;

-- Add unique constraint on reference_number if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'queue_entries_reference_number_key'
    ) THEN
        ALTER TABLE public.queue_entries 
        ADD CONSTRAINT queue_entries_reference_number_key UNIQUE (reference_number);
    END IF;
END $$;

-- Add check constraint on student_type if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'check_student_type'
    ) THEN
        ALTER TABLE public.queue_entries 
        ADD CONSTRAINT check_student_type CHECK (
            (student_type)::text = ANY (
                (ARRAY['Student'::character varying, 'Graduated'::character varying])::text[]
            )
        );
    END IF;
END $$;

-- Create trigger for updating priority status
CREATE TRIGGER trigger_update_priority
    BEFORE INSERT OR UPDATE ON public.queue_entries
    FOR EACH ROW
    EXECUTE FUNCTION update_priority_status();

-- Update existing records to set is_priority based on flags
UPDATE public.queue_entries 
SET is_priority = (COALESCE(is_pwd, FALSE) OR COALESCE(is_senior, FALSE) OR COALESCE(is_pregnant, FALSE))
WHERE is_priority IS NULL OR is_priority != (COALESCE(is_pwd, FALSE) OR COALESCE(is_senior, FALSE) OR COALESCE(is_pregnant, FALSE));

DO $$
BEGIN
    RAISE NOTICE 'Queue entries table schema updated successfully';
END $$;

